const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {LuaFactory} = require('wasmoon');
const {createCanvas} = require('@napi-rs/canvas');
const root = path.resolve(__dirname, '..');
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const subtract = (a, b) => a.map((value, i) => value - b[i]);
function intersection(origin, direction, a, b, c) {
    const ab = subtract(b, a), ac = subtract(c, a), p = cross(direction, ac), determinant = dot(ab, p);
    if (Math.abs(determinant) < 1e-10) return Infinity;
    const fromA = subtract(origin, a), u = dot(fromA, p) / determinant;
    if (u < -1e-8 || u > 1 + 1e-8) return Infinity;
    const q = cross(fromA, ab), v = dot(direction, q) / determinant;
    if (v < -1e-8 || u + v > 1 + 1e-8) return Infinity;
    const t = dot(ac, q) / determinant;
    return t >= -1e-8 ? Math.max(0, t) : Infinity;
}
function reference(heights, origin, direction) {
    let first = Infinity;
    for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) {
        const k = y * 25 + x;
        const a = [x, y, heights[k] * 16], b = [x + 1, y, heights[k + 1] * 16];
        const c = [x + 1, y + 1, heights[k + 26] * 16], d = [x, y + 1, heights[k + 25] * 16];
        first = Math.min(first, intersection(origin, direction, a, b, c), intersection(origin, direction, a, c, d));
    }
    return first === Infinity ? null : [origin[0] + direction[0] * first, origin[1] + direction[1] * first];
}
(async () => {
    const factory = new LuaFactory(), lua = await factory.createEngine();
    try {
        await lua.doString('raycast = (function() ' + fs.readFileSync(path.join(root, 'src/native/raycast.lua'), 'utf8') + ' end)()');
        const realm = {window: {}, document: {createElement: () => createCanvas(65, 65)}, Uint8Array, Uint32Array, Math};
        vm.runInNewContext(fs.readFileSync(path.join(root, 'web/shadows.js'), 'utf8'), realm);
        const terrains = [
            () => 1,
            x => Math.max(1, Math.min(3, x - 10)),
            x => Math.max(1, 3 - Math.abs(x - 12)),
            (x, y) => 1 + Math.max(0, 3 - Math.max(Math.abs(x - 12), Math.abs(y - 12)))
        ];
        let checked = 0;
        for (const terrain of terrains) {
            const heights = Array.from({length: 625}, (_, i) => terrain(i % 25, Math.floor(i / 25)));
            for (const phase of [.2, .31, .5, .72, .76, .78]) {
                const t = ((Math.floor(phase * 48) + .5) / 48 - .18) / .61;
                const angle = -Math.PI * .92 + t * Math.PI * 1.1, altitude = .33 + Math.sin(t * Math.PI) * 1.8;
                const dx = Math.cos(angle) / (16 * altitude), dy = Math.sin(angle) / (16 * altitude);
                for (const origin of [[10.5, 12.5, 60], [12, 12, 96], [9.125, 11.875, 64], [-.5, 12, 80], [23.5, 23.5, 80]]) {
                    const expected = reference(heights, origin, [dx, dy, -1]);
                    await lua.doString(`local heights={${heights.join(',')}}; local x,y=raycast(heights,{},${origin.join(',')},${dx},${dy}); hit_x=x;hit_y=y`);
                    const actualX = lua.global.get('hit_x'), actualY = lua.global.get('hit_y');
                    if (expected) {
                        assert(Math.abs(actualX - expected[0]) < 1e-7 && Math.abs(actualY - expected[1]) < 1e-7, `native first surface: ${origin}, phase ${phase}`);
                    } else assert(actualX == null, `native ray must leave world: ${origin}, phase ${phase}`);
                    const packed = new Uint32Array([64 | (64 << 10) | (origin[2] << 20)]);
                    const web = realm.window.MareShadows(packed.buffer, {probe: {cast: [0, 1]}}, {});
                    web.prepare(heights.join(','), `probe,${origin[0]},${origin[1]},0,0`, phase, 1);
                    const field = web.inspect().field, expectedField = new Uint8Array(field.length);
                    if (expected) {
                        const x = Math.max(0, Math.min(1535, Math.round(expected[0] * 64))), y = Math.max(0, Math.min(1535, Math.round(expected[1] * 64)));
                        for (let row = y; row <= Math.min(1535, y + 2); row++) for (let column = x; column <= Math.min(1535, x + 2); column++) expectedField[row * 1536 + column] = 1;
                    }
                    assert.deepEqual(field, expectedField, `web first surface: ${origin}, phase ${phase}`);
                    checked++;
                }
            }
            for (const [dx, dy] of [[0, .05], [0, -.05], [.05, 0], [-.05, 0], [.05, .05], [-.05, -.05]]) {
                const origin = [12, 12, 96], expected = reference(heights, origin, [dx, dy, -1]);
                await lua.doString(`local x,y=raycast({${heights.join(',')}},{},12,12,96,${dx},${dy});hit_x=x;hit_y=y`);
                assert(Math.abs(lua.global.get('hit_x') - expected[0]) < 1e-7 && Math.abs(lua.global.get('hit_y') - expected[1]) < 1e-7, 'axis and shared-vertex traversal');
                checked++;
            }
        }
        for (const phase of [.31,.5,.72]) {
            const heights=Array(625).fill(1),origin=[10,12,60];
            const t=((Math.floor(phase*48)+.5)/48-.18)/.61,angle=-Math.PI*.92+t*Math.PI*1.1,altitude=.33+Math.sin(t*Math.PI)*1.8;
            const dx=Math.cos(angle)/(16*altitude),dy=Math.sin(angle)/(16*altitude),px=10+dx*28,py=12+dy*28;
            const onDeck=px>=9&&px<=11&&py>=11&&py<=13,expected=onDeck?[px,py]:reference(heights,origin,[dx,dy,-1]);
            await lua.doString(`local decks={};for y=11,12 do for x=9,10 do decks[y*24+x+1]=32 end end;local x,y,z=raycast({${heights.join(',')}},decks,10,12,60,${dx},${dy});hit_x=x;hit_y=y;hit_z=z`);
            assert(Math.abs(lua.global.get('hit_x')-expected[0])<1e-7&&Math.abs(lua.global.get('hit_y')-expected[1])<1e-7,'Bridge deck is the first receiving surface only inside its footprint');
            assert(Math.abs(lua.global.get('hit_z')-(onDeck?32:16))<1e-7,'Bridge ray reports receiver elevation');
            const packed=new Uint32Array([64|(64<<10)|(60<<20)]),web=realm.window.MareShadows(packed.buffer,{probe:{cast:[0,1]},b6_0:{}},{});
            web.prepare(heights.join(','),'probe,10,12,0,0;b6_0,9,11,32,0',phase,1);
            const inspection=web.inspect(),field=onDeck?inspection.deckField:inspection.field,expectedField=new Uint8Array(field.length),x=Math.round(expected[0]*64),y=Math.round(expected[1]*64);
            for(let row=y;row<=y+2;row++)for(let column=x;column<=x+2;column++)expectedField[row*1536+column]=1;
            assert.deepEqual(field,expectedField,'Web/native bridge projection parity');checked++;
            assert(!(onDeck?inspection.field:inspection.deckField).some(value=>value),'Shadow is not duplicated onto a different receiving elevation');
        }
        await lua.doString('local h={};for i=1,625 do h[i]=1 end;local x,y,z=raycast(h,{[12*24+10+1]=32},10.5,12.5,20,0,0);hit_z=z');
        assert.equal(lua.global.get('hit_z'),16,'Rays starting below a bridge continue toward underlying ground');
        for(const name of ['assets','bits','binary','work','pixels','runs','surface','raycast','shadow_cache','shadows'])await factory.mountFile(`lua/native/${name}.lua`,fs.readFileSync(path.join(root,`src/native/${name}.lua`)));
        await lua.doString("NativeShadows=require('lua.native.shadows');function nativeShadowAt(x,y,deck) local i=y*native_shadow.n+x;local field=deck and native_shadow.deck_field or native_shadow.field;return (field[i//32+1]&(1<<(i%32)))~=0 end");
        const nativeAt=lua.global.get('nativeShadowAt');
        async function nativeColumn(words,x,y,extra=''){
            await factory.mountFile('assets/shadow-shapes.bin',new Uint8Array(words.buffer,words.byteOffset,words.byteLength));
            const scene=`column,${x},${y},16,0${extra}`;
            await lua.doString(`local heights={};for i=1,625 do heights[i]=1 end;native_shadow=NativeShadows.new({sprites={column={cast={0,${words.length}}},b5_0={}}},heights);native_shadow:prepare(table.concat(heights,','),${JSON.stringify(scene)},.76,1)`);
        }
        const columnHeights=Array(625).fill(1),columnPhase=.76;
        const columnT=((Math.floor(columnPhase*48)+.5)/48-.18)/.61,columnAngle=-Math.PI*.92+columnT*Math.PI*1.1,columnAltitude=.33+Math.sin(columnT*Math.PI)*1.8;
        const columnDx=Math.cos(columnAngle)/(16*columnAltitude),columnDy=Math.sin(columnAngle)/(16*columnAltitude);
        const columnPoints=new Uint32Array([64|(64<<10)|(1<<20)|(15<<28),64|(64<<10)|(17<<20)|(15<<28),64|(64<<10)|(33<<20)|(7<<28)]);
        const columnShadow=realm.window.MareShadows(columnPoints.buffer,{column:{cast:[0,columnPoints.length]}},{});
        columnShadow.prepare(columnHeights.join(','),'column,10.5,12.5,16,0',columnPhase,1);
        const columnField=columnShadow.inspect().field;
        await nativeColumn(columnPoints,10.5,12.5);
        for(let z=1;z<=40;z+=.25){
            const x=Math.round((10.5+columnDx*z)*64)+1,y=Math.round((12.5+columnDy*z)*64)+1;
            assert(columnField[y*1536+x],'Contiguous opaque vertical pixels cast a continuous shadow at low sun');
            assert(await nativeAt(x,y),'Native compact columns retain their continuous shadow');
        }
        const separatedPoints=new Uint32Array([64|(64<<10)|(1<<20)|(9<<28),64|(64<<10)|(30<<20)|(10<<28)]);
        const separatedShadow=realm.window.MareShadows(separatedPoints.buffer,{column:{cast:[0,separatedPoints.length]}},{});
        separatedShadow.prepare(columnHeights.join(','),'column,10.5,12.5,16,0',columnPhase,1);
        const gapX=Math.round((10.5+columnDx*20)*64)+1,gapY=Math.round((12.5+columnDy*20)*64)+1;
        assert.equal(separatedShadow.inspect().field[gapY*1536+gapX],0,'A physical gap between caster sections remains unshadowed');
        await nativeColumn(separatedPoints,10.5,12.5);
        assert.equal(await nativeAt(gapX,gapY),false,'Native compact columns retain physical gaps');
        const clippedX=-columnDx+.0001,clippedY=24-columnDy-.0001;
        assert.equal(reference(columnHeights,[clippedX,clippedY,16],[columnDx,columnDy,-1]),null);
        assert.equal(reference(columnHeights,[clippedX,clippedY,31],[columnDx,columnDy,-1]),null);
        const clippedPoints=new Uint32Array([64|(64<<10)|(15<<28)]);
        const clippedShadow=realm.window.MareShadows(clippedPoints.buffer,{column:{cast:[0,1]}},{});
        clippedShadow.prepare(columnHeights.join(','),`column,${clippedX},${clippedY},16,0`,columnPhase,1);
        assert.equal(clippedShadow.inspect().field[1535*1536],1,'A visible sample survives when both ends of its column miss the map');
        await nativeColumn(clippedPoints,clippedX,clippedY);
        assert(await nativeAt(0,1535),'Native clipping retains an interior sample even when both endpoints miss');
        const receiverCases=[
            {name:'A bridge receives an interior sample even when both endpoints hit the same ground triangle',words:[64|(64<<10)|(16<<20)|(3<<28)],x:9.85,y:12.91,extra:';b5_0,10,12,32,0',z:34,receiver:32},
            {name:'Ground receives the shadow between two disconnected decks at the same elevation',words:[64|(64<<10)|(30<<20)|(15<<28)],x:9.5,y:11.9,extra:';b5_0,10,12,32,0;b5_0,12,13,32,0',z:53,receiver:16},
            {name:'Adjacent opaque samples retain the ground shadow through a diagonal deck gap',words:[64|(64<<10)|(17<<20),64|(64<<10)|(18<<20)],x:10.99-columnDx,y:12.99-columnDy,extra:';b5_0,10,12,32,0;b5_0,11,13,32,0',z:33.125,receiver:16},
        ];
        for(const sample of receiverCases){
            const words=new Uint32Array(sample.words),shadow=realm.window.MareShadows(words.buffer,{column:{cast:[0,words.length]},b5_0:{}},{});
            shadow.prepare(columnHeights.join(','),`column,${sample.x},${sample.y},16,0${sample.extra}`,columnPhase,1);
            const x=Math.round((sample.x+columnDx*(sample.z-sample.receiver))*64),y=Math.round((sample.y+columnDy*(sample.z-sample.receiver))*64);
            const field=sample.receiver===32?shadow.inspect().deckField:shadow.inspect().field;
            assert.equal(field[y*1536+x],1,sample.name);
            await nativeColumn(words,sample.x,sample.y,sample.extra);
            assert(await nativeAt(x,y,sample.receiver===32),`Native: ${sample.name}`);
        }
        console.log(`PASS raycast: ${checked} first-surface rays, hills, map exits, axes, shared vertices, compact columns and web/native parity`);
    } finally {
        lua.global.close();
    }
})().catch(error => {console.error(error); process.exitCode = 1;});
