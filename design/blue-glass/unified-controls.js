// Review-only styling and states. Does not invoke any Android/vehicle controls.
if(params.get('controls')==='unified'){
 const root=document.querySelector('.screen');root.classList.add('unified');
 const mark=()=>'<span class="frame-mark" aria-hidden="true"></span>';
 function decorate(scope){
  scope.querySelectorAll('.selected,.segmented button.active,.toggle,.dock .play,.dock .climate,.action-main').forEach(el=>{
   if(![...el.children].some(c=>c.classList.contains('frame-mark')))el.insertAdjacentHTML('beforeend',mark());
  });
 }
 function copiedDock(external){
  const el=document.querySelector('.dock').cloneNode(true);
  el.querySelectorAll('.frame-mark').forEach(x=>x.remove());
  el.querySelector('[title="首页"]').classList.toggle('selected',!external);
  if(external){
   el.querySelector('.dock-song strong').textContent='晴天';
   el.querySelector('.dock-song small').textContent='周杰伦 · 网易云音乐';
   el.querySelector('.dock-lyric').textContent='故事的小黄花';
  }
  return el.outerHTML;
 }
 if(view==='controls'){
  root.querySelector('.workspace').outerHTML=`<section class="controls-workspace"><header class="controls-title"><h1>全局底栏与选中态</h1><p>深蓝玻璃 · 四角框线 · 1920 × 1080 设计示例</p></header><div class="dock-study"><div class="dock-study-caption"><span>桌面：首页选中</span><span>完整底栏 · 96 px 高 · 触控尺寸保持不变</span></div>${copiedDock(false)}</div><div class="dock-study"><div class="dock-study-caption"><span>其他应用：保持同一条全局底栏</span><span>首页不高亮 · 音乐与空调继续可见</span></div>${copiedDock(true)}</div><div class="controls-grid"><article class="card controls-panel"><h2>图标控件<small>58 × 58 px 示例</small></h2><div class="state-examples"><div class="state-example">${button('home','普通态')}<span>普通</span></div><div class="state-example">${button('home','选中态','selected')}<span>选中</span></div><div class="state-example">${button('home','按下态','is-pressed')}<span>按下</span></div><div class="state-example"><button class="icon-button" disabled aria-label="禁用态">${icon('home')}</button><span>禁用</span></div><div class="state-example">${button('pause','主操作','action-main')}<span>主操作</span></div></div><p class="controls-note">选中：主题色短角线 + 低透明底色。按下：局部底色加深。<br>播放 / 暂停为即时操作，以中性角线区分，不持续显示为导航选中。</p></article><article class="card controls-panel"><h2>设置选项<small>共用角线、颜色与状态层级</small></h2><div class="segmented"><button>智能调色</button><button>跟随系统</button><button>浅色</button><button class="active">深色</button></div><div class="choice-examples"><button>经典</button><button class="selected">深蓝玻璃${icon('check')}</button></div><p class="controls-note">大选项角线 10–12 px，图标按钮 7–8 px。<br>标签页保留短下划线；颜色圆点保留标准选色环。</p></article></div></section>`;
  root.querySelector('.page-indicator')?.remove();
  root.querySelector('.preview-mark').textContent='设计示例 · 非实时数据';
  root.querySelector(':scope > .dock [title="首页"]').classList.add('selected');
 }
 decorate(root);
 root.querySelectorAll('.selected,.segmented button.active').forEach(el=>el.setAttribute('aria-pressed','true'));
 // Make the static settings preview reflect the same angular dock vocabulary.
 root.querySelectorAll('.style-option.selected>.frame-mark').forEach(el=>el.style.setProperty('--mark-size','12px'));
}
