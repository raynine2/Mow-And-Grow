import json,math
V='/tmp/claude-0/-home-claude/f46c7759-369a-5eb8-818e-15ab365e1c8d/scratchpad/vfx/'
NUM=['Rate','Drag','LightEmission','LightInfluence','Brightness','ZOffset','VelocityInheritance','TimeScale','ShapePartial']
BOOL=['LockedToPart','FlipbookStartRandom','WindAffectsDrag']
ENUM=['EmissionDirection','Shape','ShapeInOut','ShapeStyle','Orientation','FlipbookLayout','FlipbookMode']
NS=['Size','Transparency','Squash']; NR=['Lifetime','Speed','Rotation','RotSpeed','FlipbookFramerate']
BEAMNUM=['TextureLength','TextureSpeed','Width0','Width1','LightEmission','LightInfluence','Brightness','Segments','CurveSize0','CurveSize1','ZOffset']
def f(x):
    if abs(x)<1e-6: return '0'
    s=('%.4g'%x)
    return s
def lua_str(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def tex(t):
    import re
    m=re.search(r'(\d{6,})',t or '')
    if t and t.startswith('rbxasset://'): return lua_str(t)
    return lua_str('rbxassetid://'+m.group(1)) if m else '""'
def conv(name,v,beam=False):
    if v is None: return None
    if isinstance(v,dict):
        t=v['t']; vv=v['v']
        if t=='NS':
            # dedupe and limit keypoints to 8 (Roblox max 20)
            return '{'+','.join('{%s,%s,%s}'%(f(a),f(b),f(c)) for a,b,c in vv)+'}'
        if t=='CS': return '{'+','.join('{%s,%s,%s,%s}'%(f(a),f(r),f(g),f(b)) for a,r,g,b in vv)+'}'
        if t=='NR': return '{%s,%s}'%(f(vv[0]),f(vv[1]))
        if t=='V3': return '{%s,%s,%s}'%tuple(f(a) for a in vv)
        if t=='V2': return '{%s,%s}'%(f(vv[0]),f(vv[1]))
        if t=='E': return lua_str(vv[1])
        return None
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,(int,float)): return f(v)
    if isinstance(v,str): return tex(v) if name=='Texture' else lua_str(v)
def emitters(pack):
    d=json.load(open(V+pack+'.json'))
    out=[]
    def walk(n,parents,host):
        c=n['c']; nm=n.get('n','')
        p=n.get('p',{})
        newhost=host
        if c=='Attachment':
            cf=p.get('CFrame',{}).get('v',[0,0,0])
            hp=host['pos'] if host else [0,0,0]
            newhost={'kind':'att','pos':[hp[0]+cf[0],hp[1]+cf[1],hp[2]+cf[2]],'size':None,'base':host['base'] if host else nm}
        elif c in('Part','MeshPart'):
            s=p.get('Size',{}).get('v',[1,1,1])
            cf=p.get('CFrame',{}).get('v',[0,0,0])
            newhost={'kind':'part','pos':(host['pos'] if host and host['kind']=='att' else [0,0,0]),'size':s,'base':nm}
        if c in('ParticleEmitter','Beam'):
            props=[]
            keys=(['Texture','Color','Transparency']+(NS+NR+NUM+BOOL+ENUM+['Acceleration','SpreadAngle']) if c=='ParticleEmitter' else ['Texture','Color','Transparency','TextureMode','FaceCamera']+BEAMNUM)
            for k in dict.fromkeys(keys):
                val=p.get(k)
                cv=conv(k,val)
                if cv is not None: props.append(f'{k}={cv}')
            a=n.get('a',{})
            if isinstance(a,dict):
                for ak in('EmitCount','EmitDelay','EmitDuration'):
                    if ak in a and isinstance(a[ak],(int,float)): props.append(f'{ak}={f(a[ak])}')
            en=p.get('Enabled',True)
            h=host or {'kind':'att','pos':[0,0,0],'size':None,'base':'?'}
            hs='{%s,%s,%s}'%tuple(f(x) for x in h['pos'])
            box='{%s,%s,%s}'%tuple(f(x) for x in h['size']) if h.get('size') else 'nil'
            out.append('\t{n=%s,c=%s,on=%s,at=%s,box=%s,%s},'%(lua_str(nm),lua_str(c),'true' if en else 'false',hs,box,','.join(props)))
        k=n.get('k') or []
        if isinstance(k,dict): k=[]
        for ch in k: walk(ch,parents+[nm],newhost)
    for r in d['roots']: walk(r,[],None)
    return out
res={}
for pk in ['LoveAura','EvilFloor','Explosion','BigBeam']:
    res[pk]=emitters(pk)
import re
def dkey(line):
    g=lambda k: (re.search(k+r'=(\{[^=]*?\}|[^,]*)',line) or [None,''])[1] if re.search(k+'=',line) else ''
    return (g('n'),g('Texture'),g('Size'),g('Width0'),g('Color'))
for pk in ['BigBeam','Explosion','EvilFloor']:
    seen=set(); keep=[]
    for line in res[pk]:
        k=dkey(line)
        if k in seen: continue
        seen.add(k); keep.append(line)
    res[pk]=keep
# LoveAura: drop the avatar's own stuff (no emitters there anyway)
hdr='''-- The owner's five free VFX packs (31 Oct: "rework the classes when u equip them like aura and fx and vfx u can use
-- these"), as data: tools/vfx-import/export.luau read each .rbxm, tools/vfx-import/aurapacks.py kept the effects.
-- Each entry is one ParticleEmitter or Beam with its own properties: n name, c class, on enabled in the pack, at where
-- it sat (studs from the pack's centre), box the size of the part it sat in (emits from that volume; nil = a point),
-- EmitCount / EmitDelay the burst the pack fires (its emitters with Rate 0 or disabled are bursts).
-- Colours are the packs' own (pink, red, blue): client/ClassVfx recolours every one per class.
--   LoveAura   a character aura: flames, lightning flicks, crescents, sparks (the HumanoidRootPart's)
--   EvilFloor  a ground circle: runes, a ripple, shock rings, wind, dots
--   Explosion  a burst: crescents, ground crack, shards, toon lightning, smoke
--   BigBeam    a beam's textures (main, shades, shockwave, spiral) for a pillar of light
return {
'''
body=''
for k,v in res.items():
    body+=f'\t{k} = {{\n'+'\n'.join('\t'+l for l in v)+'\n\t},\n'
open('/home/claude/mow-and-grow/src/shared/AuraPacks.luau','w').write(hdr+body+'}\n')
print({k:len(v) for k,v in res.items()})
