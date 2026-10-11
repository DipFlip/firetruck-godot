"""Offline smooth unions with touching/paint boundaries and retained toy joints."""
from pathlib import Path
import json, struct
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds/blend'
OUT.mkdir(parents=True,exist_ok=True)


def sdf(p, points):
    inverse=np.asarray(p['inverse'])
    q=np.einsum('ij,kj->ik',points-p['centre'],inverse)
    r=np.asarray(p['radii'])
    if p['kind'] in ('box','rounded_box'):
        radius=p.get('rounding',0)
        d=np.abs(q)-r+radius
        return np.linalg.norm(np.maximum(d,0),axis=1)+np.minimum(d.max(1),0)-radius
    if p['kind']=='cylinder':
        radial=(np.linalg.norm(q[:,[0,2]]/r[[0,2]],axis=1)-1)*min(r[0],r[2])
        d=np.stack((radial,np.abs(q[:,1])-r[1]),axis=1)
        return np.linalg.norm(np.maximum(d,0),axis=1)+np.minimum(d.max(1),0)
    a=np.linalg.norm(q/r,axis=1); b=np.linalg.norm(np.einsum('ij,jk->ik',q/(r*r),inverse),axis=1)
    return np.divide(a*(a-1),b,out=np.full_like(a,-r.min()),where=b>1e-8)


def expand(name, parts):
    if not name.startswith('tree'): return parts
    result=[]
    for p in parts:
        v=np.asarray(p['raw']); idx=np.asarray(p['indices'],dtype=int)
        if not len(idx): idx=np.arange(len(v))
        unique,inv=np.unique(np.round(v,5),axis=0,return_inverse=True)
        tri=inv[idx].reshape(-1,3)
        a=tri[:,[0,1,2]].ravel(); b=tri[:,[1,2,0]].ravel()
        _,labels=connected_components(coo_matrix((np.ones(len(a)),(a,b)),shape=(len(unique),len(unique))),directed=False)
        for group in np.unique(labels):
            chosen=np.flatnonzero(labels[inv]==group)
            if not len(chosen): continue
            remap=np.full(len(v),-1); remap[chosen]=np.arange(len(chosen))
            triangles=idx.reshape(-1,3)
            triangles=triangles[np.all(remap[triangles]>=0,axis=1)]
            points=v[chosen]; lo,hi=points.min(0),points.max(0); radii=(hi-lo)/2
            # Both authored leaf palettes include olive/yellow-green shades.
            # The brown trunk palette is the only non-foliage surface.
            colour=p['colour']; foliage=not np.allclose(colour, parts[0]['colour'])
            centre=(hi+lo)/2; inverse=np.eye(3)
            if foliage:
                # Recover the authored rotated ellipsoid, not its larger AABB.
                # A bounds approximation inflated leaves before any blending.
                origin=points.mean(0);q=points-origin
                design=np.c_[q[:,0]**2,q[:,1]**2,q[:,2]**2,2*q[:,0]*q[:,1],2*q[:,0]*q[:,2],2*q[:,1]*q[:,2],q]
                coefficients=np.linalg.lstsq(design,np.ones(len(q)),rcond=None)[0]
                a,b,c,d,e,f=coefficients[:6]
                matrix=np.array([[a,d,e],[d,b,f],[e,f,c]])
                shift=-.5*np.linalg.solve(matrix,coefficients[6:])
                divisor=1+np.einsum('i,ij,j->',shift,matrix,shift)
                eigenvalues,axes=np.linalg.eigh(matrix/divisor)
                residual=np.max(np.abs(np.einsum('ij,j->i',design,coefficients)-1))
                assert eigenvalues.min()>0 and residual<.001, 'Foliage must fit its source ellipsoid'
                centre=origin+shift;radii=1/np.sqrt(eigenvalues);inverse=axes.T
            result.append(dict(raw=points.tolist(),normals=np.asarray(p['normals'])[chosen].tolist(),indices=remap[triangles].ravel().tolist(),kind='ellipsoid',centre=centre.tolist(),radii=radii.tolist(),inverse=inverse.tolist(),colour=colour,category=3,bone=0,eligible=foliage))
    return result


def contact_groups(name, parts):
    adjacency=np.eye(len(parts),dtype=bool)
    for i,a in enumerate(parts):
        if not a['eligible']: continue
        for j in range(i):
            b=parts[j]
            if not b['eligible']: continue
            if not name.startswith('tree') and a['colour']!=b['colour']: continue
            if name.startswith('person') and not name.endswith('_joined') and a['bone']!=b['bone']: continue
            # A positive gap, however small, is not an invitation to bridge it.
            contact=min(sdf(a,np.asarray(b['raw'])).min(),sdf(b,np.asarray(a['raw'])).min())<=.001
            adjacency[i,j]=adjacency[j,i]=contact
    _,labels=connected_components(coo_matrix(adjacency),directed=False)
    return [np.flatnonzero(labels==g) for g in np.unique(labels)],adjacency


def union_surface(name, parts, level, adjacency):
    step=.02 if name=='hydrant' else .05 if name.startswith('person') else .09
    k=level*(.18 if name=='hydrant' else .24 if name.startswith('person') else .65)
    lo=np.full(3,np.inf); hi=-lo
    for p in parts:
        extent=np.abs(np.linalg.inv(p['inverse']))@np.asarray(p['radii'])
        lo=np.minimum(lo,np.asarray(p['centre'])-extent);hi=np.maximum(hi,np.asarray(p['centre'])+extent)
    lo-=k+.10;hi+=k+.10
    shape=np.ceil((hi-lo)/step).astype(int)+1
    grid=np.stack(np.meshgrid(*(lo[i]+np.arange(shape[i])*step for i in range(3)),indexing='ij'),axis=-1).astype(np.float32)
    flat=grid.reshape(-1,3); distance=np.full(len(flat),1e6,dtype=np.float32); colour=np.zeros_like(flat)
    bone_weights=np.zeros((len(flat),7),dtype=np.float32)
    nearest=np.zeros(len(flat),dtype=int); nearest_distance=distance.copy()
    for i,p in enumerate(parts):
        d=sdf(p,flat)
        h=np.clip(.5+.5*(d-distance)/k,0,1)
        h=np.where(adjacency[i,nearest],h,(d>=distance).astype(float))
        distance=d*(1-h)+distance*h-k*h*(1-h)
        colour=np.asarray(p['colour'])*(1-h[:,None])+colour*h[:,None]
        bone_weights*=h[:,None]
        bone_weights[:,p['bone']]+=1-h
        nearer=d<nearest_distance;nearest[nearer]=i;nearest_distance[nearer]=d[nearer]
    field=distance.reshape(shape)
    gradients=np.stack(np.gradient(field,step),axis=-1).reshape(-1,3)
    offsets=np.array([(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)])
    cells=np.stack(np.meshgrid(*(np.arange(n-1) for n in shape),indexing='ij'),axis=-1).reshape(-1,3)
    corners=np.array([np.ravel_multi_index((cells+off).T,shape) for off in offsets]).T
    values=distance[corners]
    corners=corners[(values.min(1)<0)&(values.max(1)>=0)]
    tetra=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
    edges=[(0,1),(1,2),(2,0),(0,3),(1,3),(2,3)]
    table=[[],[0,3,2],[0,1,4],[1,4,2,2,4,3],[1,2,5],[0,3,5,0,5,1],[0,2,5,0,5,4],[5,4,3],[3,4,5],[4,5,0,5,2,0],[1,5,0,5,3,0],[5,2,1],[3,4,2,2,4,1],[4,1,0],[2,3,0],[]]
    vertices=[];normals=[];colors=[];weights=[]
    for t in tetra:
        ids=corners[:,t]; case=((distance[ids]<0)*[1,2,4,8]).sum(1)
        for c in range(1,15):
            selected=ids[case==c]
            if not len(selected):continue
            for edge in table[c]:
                a,b=(selected[:,x] for x in edges[edge]); alpha=distance[a]/(distance[a]-distance[b])
                vertices.append(flat[a]+(flat[b]-flat[a])*alpha[:,None])
                normals.append(gradients[a]+(gradients[b]-gradients[a])*alpha[:,None])
                colors.append(colour[a]+(colour[b]-colour[a])*alpha[:,None])
                weights.append(bone_weights[a]+(bone_weights[b]-bone_weights[a])*alpha[:,None])
            # Transpose edge-major buffers to triangle order per tetrahedron.
            count=len(table[c]);
            for array in (vertices,normals,colors,weights):
                chunk=np.stack(array[-count:],axis=1).reshape(-1,array[-1].shape[-1])
                del array[-count:];array.append(chunk)
    v=np.concatenate(vertices); n=np.concatenate(normals);col=np.concatenate(colors);w=np.concatenate(weights)
    tri=v.reshape(-1,3,3);tn=n.reshape(-1,3,3)
    flip=(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])*tn.mean(1)).sum(1)>0
    for arr in (v,n,col,w):
        q=arr.reshape(-1,3,arr.shape[-1]);q[flip]=q[flip][:,[0,2,1]]
    _,first,index=np.unique(np.round(v,6),axis=0,return_index=True,return_inverse=True)
    v,n,col,w=v[first],n[first],col[first],w[first]
    n/=np.maximum(1e-8,np.linalg.norm(n,axis=1))[:,None]
    return v,n,col,w,index


def build(name, source, level):
    parts=expand(name,source)
    groups,adjacency=contact_groups(name,parts)
    buffers=[];categories=[];offset=0
    for group in groups:
        chosen=[parts[i] for i in group]
        if len(group)>1:
            v,n,col,w,idx=union_surface(name,chosen,level,adjacency[np.ix_(group,group)])
        else:
            p=chosen[0];v=np.asarray(p['raw']);n=np.asarray(p['normals'])
            col=np.tile(p['colour'],(len(v),1));w=np.zeros((len(v),7));w[:,p['bone']]=1
            idx=np.asarray(p['indices'],dtype=int)
            if not len(idx):idx=np.arange(len(v))
        categories.append(np.tile([chosen[0]['category'],0],(len(v),1)))
        buffers.append((v,n,col,w,idx+offset));offset+=len(v)
    v,n,col,w,idx=(np.concatenate([b[i] for b in buffers]) for i in range(5))
    bones=np.argsort(w,axis=1)[:,-4:]
    weights=np.take_along_axis(w,bones,axis=1)
    weights/=np.maximum(weights.sum(1)[:,None],1e-8)
    path=OUT/f'{name}_{round(level*100):03}.meshbin'
    with path.open('wb') as f:
        f.write(struct.pack('<II',len(v),len(idx)))
        for a in (v,n,col,np.concatenate(categories)):f.write(np.asarray(a,dtype='<f4').tobytes())
        f.write(np.asarray(bones,dtype='<i4').tobytes())
        f.write(np.asarray(weights,dtype='<f4').tobytes())
        f.write(np.asarray(idx,dtype='<u4').tobytes())
    print(path.name,len(v),'vertices',len(idx)//3,'triangles; unions:',[len(g) for g in groups if len(g)>1],flush=True)

if __name__=='__main__':
    models=json.loads((ROOT/'assets/scenery/blend_primitives.json').read_text())
    models['person_joined']=models['person']
    for name,parts in models.items():
        for level in [.10,.15,.25,.5,.75,1]:build(name,parts,level)
