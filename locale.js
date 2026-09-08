(function () {
'use strict';
var messages;
function select(code) {
 messages=window.MareWebLocales[code];
 if(!messages)throw Error('unknown locale: '+code);
 document.documentElement.lang=code==='pt'?'pt-BR':code;
 document.title=messages.title;
 document.getElementById('gameCanvas').setAttribute('aria-label',messages.canvas);
 document.getElementById('progress').textContent=messages.loading;
 document.querySelector('#loading small').textContent=messages.controls;
 document.getElementById('retry').textContent=messages.retry;
}
window.MareLocale={select:select,init:function(options){var fields=options.split(',');select(fields.length<6?'pt':fields[5]);},failure:function(){return messages.failure;}};
})();
