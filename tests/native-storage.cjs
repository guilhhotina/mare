const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const {LuaFactory} = require('wasmoon');
const root = path.resolve(__dirname, '..');
(async () => {
    const lua = await new LuaFactory().createEngine();
    const sources = [['Catalog', 'catalog'], ['LocaleData', 'locales'], ['I18n', 'i18n'], ['Activities','activities'],['Appearance','appearance'],['InteractionAnchors','interaction_anchors'],['Paths','paths'],['Life','life'],['TrafficPaths','traffic_paths'],['Traffic','traffic'],['TrafficStore','traffic_store'],['World','world']].map(([name,file]) => 'local ' + name + '=(function()\n' + fs.readFileSync(path.join(root, 'src', file + '.lua'), 'utf8') + '\nend)()\n').join('');
    const migrated = JSON.parse(execFileSync('python', ['-c', `import json, sqlite3, tempfile
from contextlib import closing
from pathlib import Path
from tools.storage_migration import migrate_storage
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'app.db'
    with closing(sqlite3.connect(path)) as db, db:
        db.execute('CREATE TABLE persistent (id INTEGER PRIMARY KEY, key TEXT UNIQUE, value TEXT)')
        for key, fixture in [('mare.island.1', 'mare3-first-completion.txt'), ('mare.island.1.backup', 'mare2-v01.txt')]:
            db.execute('INSERT INTO persistent (key,value) VALUES (?,?)', (key, Path('tests/fixtures',fixture).read_text().strip()))
    migrate_storage(path)
    with closing(sqlite3.connect(path)) as db:
        print(json.dumps(dict(db.execute('SELECT key,value FROM persistent'))))
`], {cwd: root, encoding: 'utf8'}));
    lua.global.set('real_save', fs.readFileSync(path.join(__dirname, 'fixtures/mare3-first-completion.txt'), 'utf8'));
    lua.global.set('legacy_save', fs.readFileSync(path.join(__dirname, 'fixtures/mare2-v01.txt'), 'utf8').trim());
    lua.global.set('migration_keys', Object.keys(migrated).join('\n'));
    lua.global.set('migration_value', key => migrated[key]);
    try {
        await lua.doString("package.preload['lua.native.bits']=function()\n" + fs.readFileSync(path.join(root, 'src/native/bits.lua'), 'utf8') + '\nend');
        await lua.doString(sources + 'local Storage=(function()\n' + fs.readFileSync(path.join(root, 'src/native/storage.lua'), 'utf8') + '\nend)()\n' + `
local checks=0
local function expect(value,message) checks=checks+1;assert(value,message) end
local function environment(data)
    local control={data=data or {},queue={},deferred=false,writes=0}
    local std={storage={}}
    std.storage.get=function(key)
        local operation={}
        function operation:callback(fn) self.fn=fn;return self end
        function operation:run()
            local function deliver() local value=control.data[key];self.fn(value and value:sub(1,4095)) end
            if control.deferred then control.queue[#control.queue+1]=deliver else deliver() end
        end
        return operation
    end
    std.storage.set=function(key,value)
        return {run=function()
            if control.stop and control.writes==control.stop then error('interrupted') end
            control.writes=control.writes+1
            if key==control.corrupt then value=value:sub(2) end
            control.data[key]=value
        end}
    end
    function control:load()
        local storage=Storage.new(std);local ready=false
        storage:load(function() ready=true end)
        if self.deferred then
            expect(not ready,'asynchronous load waits for its callbacks')
            while #self.queue>0 do table.remove(self.queue,1)() end
        end
        expect(ready,'load completes after all requested values')
        return storage
    end
    return control,std
end
local data={}
for key in (migration_keys..string.char(10)):gmatch('(.-)'..string.char(10)) do data[key]=migration_value(key) end
local migrated=environment(data)
migrated.deferred=true
local loaded=migrated:load()
expect(loaded.values['mare.island.1']==real_save,'Python migration and asynchronous Lua load preserve the real 4828-byte save')
local world=World.decode(loaded.values['mare.island.1'])
expect(world and world.life_time==60090 and world.completed_lots==1 and #world.jobs==0 and #world.people==1,'actual completed house and traveling resident survive native-sized reads')
local upgraded=World.encode(world)
local upgraded_world=World.decode(upgraded)
expect(upgraded_world and World.encode(upgraded_world)==upgraded,'migrated completion and traveling resident roundtrip without losing progress')
expect(loaded.values['mare.island.1.backup']==legacy_save and World.decode(legacy_save),'migrated legacy backup retains MARE2 compatibility')
local control,std=environment()
local storage=control:load()
local large=string.rep('0123456789',10000)
expect(storage:save(1,real_save,''),'first complete native save commits')
expect(storage:save(1,large,real_save),'100000-byte payload commits through bounded native reads')
local restarted=control:load()
expect(restarted.values['mare.island.1']==large and restarted.values['mare.island.1.backup']==real_save,'restart restores full latest save and previous backup')
local before=control.data['mare.island.1']
expect(not restarted:write('mare.island.1',large..'x') and control.data['mare.island.1']==before,'oversized value cannot replace the committed pointer')
for stop=0,34 do
    local interrupted={}
    for key,value in pairs(control.data) do interrupted[key]=value end
    local attempt=environment(interrupted)
    local writer=attempt:load();attempt.stop=stop
    local ok=pcall(function() writer:write('mare.island.1',string.rep('z',100000)) end)
    expect(not ok,'interruption occurs before the next commit')
    attempt.stop=nil
    local recovered=attempt:load()
    expect(recovered.values['mare.island.1']==large and recovered.values['mare.island.1.backup']==real_save,'every precommit interruption preserves committed save and backup')
end
control.corrupt='mare.island.1.chunk.0.1'
expect(not storage:write('mare.island.1',string.rep('z',100000)),'failed chunk readback cannot commit a new save')
control.corrupt=nil
expect(control:load().values['mare.island.1']==large,'failed chunk verification leaves the committed bank readable')
for i=1,4 do expect(storage:write('mare.island.1',large),'successive saves reuse bounded banks') end
local parts=0
for key in pairs(control.data) do if key:match('^mare%.island%.1%.chunk%.') then parts=parts+1 end end
expect(parts<=68,'repeated maximum-size saves cannot grow unbounded storage keys')
local bank=control.data['mare.island.1']:match('^MARECHUNK1,([01]),')
local first='mare.island.1.chunk.'..bank..'.1'
local intact=control.data[first]
for _,broken in ipairs({false,'short','x'..intact:sub(2)}) do
    control.data[first]=broken or nil
    local damaged=control:load()
    expect(damaged.values['mare.island.1']~='' and not World.decode(damaged.values['mare.island.1']),'missing, short or checksum-mismatched chunk stays visibly invalid')
    expect(damaged.values['mare.island.1.backup']==real_save,'damaged active bank does not damage backup')
end
local recovery_data={}
for key,value in pairs(control.data) do recovery_data[key]=value end
local recovery=environment(recovery_data)
local recovered=recovery:load()
local previous=recovered.values['mare.island.1']
previous=World.decode(previous) and previous or ''
recovery.stop=1
expect(not pcall(function() recovered:save(1,real_save,previous) end),'recovery save is interrupted before committing')
recovery.stop=nil
expect(recovery:load().values['mare.island.1.backup']==real_save,'interrupted recovery never replaces the last valid backup with corrupt data')
control.data[first]=intact
control.data['mare.island.1']='MARECHUNK1,0,999999999,100000,0'
local invalid=control:load()
expect(invalid.values['mare.island.1']==control.data['mare.island.1'],'invalid manifest is not mistaken for an empty slot')
expect(storage:write('mare.options','sound,motion,2,1,2'),'short options retain the existing storage interface')
expect(control:load().values['mare.options']=='sound,motion,2,1,2','short options survive restart')
print('PASS native storage: '..checks..' assertions.')
`);
    } finally {
        lua.global.close();
    }
})().catch(error => { console.error(error); process.exitCode = 1; });
