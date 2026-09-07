from pathlib import Path
import json, shutil, re
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'web';(out/'vendor').mkdir(parents=True,exist_ok=True)
from type_art import build as build_type
build_type()
rows=json.loads((ROOT/'assets/catalog.json').read_text())
font=ImageFont.truetype(str(ROOT/'web/vendor/PixelifySans.ttf'),13)
for row in rows:
 words=row[0].split();line='';rest=[]
 for word in words:
  if rest or sum(max(2,round(font.getlength(ch)))*2 for ch in (line+' '+word).strip())>184:rest.append(word)
  else:line=(line+' '+word).strip()
 row.extend([line,' '.join(rest)])
def lua(x):
 if isinstance(x,str):return json.dumps(x,ensure_ascii=True)
 if isinstance(x,list):return '{'+','.join(lua(v) for v in x)+'}'
 return str(x)
catalog='return '+lua(rows)+'\n'
(ROOT/'src/catalog.lua').write_text(catalog)
casters={}
caster_lua='{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in casters.items())+'}'
bundle='local Catalog=(function()\n'+catalog+'end)()\nlocal Casters='+caster_lua+'\nlocal World=(function()\n'+(ROOT/'src/world.lua').read_text()+'\nend)()\nlocal Lighting=(function()\n'+(ROOT/'src/lighting.lua').read_text()+'\nend)()\n'+(ROOT/'src/main.lua').read_text()
accents={'MARE':'MARÉ','voce':'você','Voce':'Você','comercio':'comércio','Comercio':'Comércio','Servicos':'Serviços','servicos':'serviços','construcoes':'construções','construcao':'construção','Construcoes':'Construções','Construcao':'Construção','opcao':'opção','opcoes':'opções','acao':'ação','ultima':'última','Ultima':'Última','acoes':'ações','costa':'costa','regiao':'região','regioes':'regiões','previa':'prévia','Previa':'Prévia','fundacoes':'fundações','Administracao':'Administração','Agua':'Água','agua':'água','Saude':'Saúde','saude':'saúde','Clinica':'Clínica','clinica':'clínica','Educacao':'Educação','educacao':'educação','Manutencao':'Manutenção','manutencao':'manutenção','eolica':'eólica','poluicao':'poluição','Energia':'Energia','Pausa':'Pausa','Diario':'Diário','diario':'diário','Proxima':'Próxima','PROXIMA':'PRÓXIMA','padrao':'padrão','onibus':'ônibus','praca':'praça','Praca':'Praça','pracas':'praças','Pracas':'Praças','comercios':'comércios','comeco':'começo','variacao':'variação','predios':'prédios','Predios':'Prédios','Edificio':'Edifício','cafe':'café','possivel':'possível','Nao':'Não','nao':'não','ja':'já','espaco':'espaço','estao':'estão','so':'só','ate':'até','pais':'país','simulacao':'simulação','limites':'limites','viario':'viário','viaria':'viária','viarias':'viárias','viarios':'viários','economicos':'econômicos','automatico':'automático','obrigatorio':'obrigatório','obrigatorios':'obrigatórios','paginas':'páginas','medio':'médio','veterinario':'veterinário','Veterinario':'Veterinário','confortavel':'confortável','invalido':'inválido','valida':'válida','numero':'número','NUMEROS':'NÚMEROS','ARQUIVO':'ARQUIVO','educacao':'educação','receber':'receber','maleavel':'maleável','especies':'espécies','selecao':'seleção','aerea':'aérea','detalhes':'detalhes','portao':'portão','rodoviaria':'rodoviária','PROXIMA':'PRÓXIMA'}
accents.update({'nivel':'nível','niveis':'níveis','peca':'peça','Manha':'Manhã','manha':'manhã','diferenca':'diferença','tracado':'traçado','Tracado':'Traçado','horario':'horário','proxima':'próxima'})
def localized(match):
 literal=match.group(0)
 if literal.startswith(chr(45)*2):return literal
 for word,replacement in accents.items():literal=re.sub(r'(?<![A-Za-z0-9_])'+word+r'(?![A-Za-z0-9_])',replacement,literal)
 literal=literal.replace("'Mare'","'Maré'").replace('A ilha e toda sua','A ilha é toda sua').replace('A terra e maleável','A terra é maleável')
 literal=literal.replace('por do sol','pôr do sol')
 literal=literal.replace('esta pausada','está pausada').replace('esta ocupado','está ocupado').replace('já esta','já está').replace('esta vazio','está vazio')
 literal=literal.replace(' a vontade',' à vontade').replace(' as ferramentas',' às ferramentas').replace('Voltar as','Voltar às')
 return ''.join(c if ord(c)<128 else ''.join('\\'+str(b).zfill(3) for b in c.encode()) for c in literal)
bundle=re.sub(r"--[^\n]*|'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"",localized,bundle)
web_bundle='local Platform=(function()\n'+(ROOT/'src/platform/web.lua').read_text()+'\nend)()\n'+bundle
(out/'game.lua').write_text(web_bundle)

shutil.copy2(ROOT/'assets/logo.png',out/'logo.png');shutil.copy2(ROOT/'assets/atlas.png',out/'atlas.png');shutil.copy2(ROOT/'assets/atlas.json',out/'atlas.json')
shutil.copy2(ROOT/'assets/shadow-shapes.bin',out/'shadow-shapes.bin')
print('Built',out,'Lua bytes',len(bundle),'total bytes',sum(p.stat().st_size for p in out.rglob('*') if p.is_file()))
shutil.copytree(out,ROOT/'dist',dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.db','*.db-*'))
