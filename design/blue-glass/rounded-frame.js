// Render-native SVG paths for this design proposal, never screenshots or blur.
if(params.has('radius')){
 const radius=Math.max(0,Math.min(40,Number(params.get('radius'))||0));
 const root=document.querySelector('.screen');root.classList.add('rounded-theme');
 function setRadius(el,r){
  el.style.setProperty('--panel-radius',r+'px');
  el.style.setProperty('--control-radius',Math.min(16,r*.5)+'px');
  el.style.setProperty('--option-radius',Math.min(20,r*.55)+'px');
  el.style.setProperty('--small-radius',Math.min(8,r*.25)+'px');
  el.style.setProperty('--cover-radius',Math.min(14,r*.45)+'px');
  el.dataset.radius=r;
 }
 setRadius(root,radius);
 if(view==='radius'){
  const weather=root.querySelector('.weather').outerHTML;
  const home=root.querySelector(':scope > .dock [title="首页"]').cloneNode(true);home.classList.add('selected');
  if(!home.querySelector('.frame-mark'))home.insertAdjacentHTML('beforeend','<span class="frame-mark" aria-hidden="true"></span>');
  const play=root.querySelector(':scope > .dock .play').outerHTML;
  const descriptions={0:'直角 · 结构清晰',12:'轻圆角 · 保留硬朗',24:'中圆角 · 推荐',40:'大圆角 · 更柔和'};
  root.querySelector('.workspace').outerHTML=`<section class="radius-workspace"><header class="radius-title"><h1>圆角设置效果</h1><p>同一套四角框线与玻璃材质 · 1920 × 1080</p></header><div class="radius-columns">${[0,12,24,40].map(r=>`<section class="radius-sample" data-sample-radius="${r}"><div class="radius-sample-heading"><strong>${r} px</strong><small>${descriptions[r]}</small></div>${weather}<div class="radius-controls">${home.outerHTML}${play}<span>选中 / 主操作<br>按钮圆角 ${Math.min(16,r*.5)} px</span></div><p class="radius-note">${r===0?'短直线角标与矩形边缘对齐。':`角标沿 ${r} px 圆角绘制短弧，<br>按钮按比例使用 ${Math.min(16,r*.5)} px 圆角。`}</p></section>`).join('')}</div><footer class="radius-rules"><span><strong>卡片：</strong>0–40 px</span><span><strong>角标：</strong>贴合曲线，保持线宽</span><span><strong>底栏：</strong>外框始终直角贴底</span><span><strong>触控：</strong>位置与尺寸保持不变</span></footer></section>`;
  root.querySelectorAll('.radius-sample').forEach(el=>setRadius(el,Number(el.dataset.sampleRadius)));
  root.querySelector('.page-indicator')?.remove();
 }
 root.querySelectorAll('.radius-demo').forEach(el=>el.innerHTML=`<span class="radius-track"><i style="width:${radius/40*100}%"></i></span>${radius}`);
 root.querySelectorAll('.preview-mark').forEach(el=>el.textContent=`圆角 ${radius} px · 设计示例 · 非实时数据`);
 root.querySelectorAll('.card').forEach(el=>el.insertAdjacentHTML('beforeend','<span class="rounded-panel-frame" aria-hidden="true"></span>'));
 function frame(el){
  const parent=el.parentElement,rct=el.getBoundingClientRect();
  const width=rct.width,height=rct.height;
  if(width<=0||height<=0)return;
  const style=getComputedStyle(parent),r=Math.min(parseFloat(style.borderTopLeftRadius)||0,width/2,height/2);
  const weight=parseFloat(getComputedStyle(el).getPropertyValue('--mark-weight'))||1.5,s=weight/2;
  const panel=el.classList.contains('rounded-panel-frame');
  const budget=panel?18:(parseFloat(getComputedStyle(el).getPropertyValue('--mark-size'))||10);
  const arc=Math.max(.01,r-s);
  let left;
  if(r>0){
   const sweep=Math.min(Math.PI/3,budget/arc),start=Math.PI+(Math.PI/2-sweep)/2,end=start+sweep;
   left=`M${r+Math.cos(start)*arc},${r+Math.sin(start)*arc}A${arc},${arc} 0 0 1 ${r+Math.cos(end)*arc},${r+Math.sin(end)*arc}`;
  }else{
   const extent=Math.min(budget,width/2-2,height/2-2);
   left=`M${s},${extent}V${s}H${extent}`;
  }
  el.dataset.frameBudget=budget;
  const paths=[`<path d="${left}"/>`,`<path d="${left}" transform="translate(${width},0) scale(-1,1)"/>`,`<path d="${left}" transform="translate(0,${height}) scale(1,-1)"/>`,`<path d="${left}" transform="translate(${width},${height}) scale(-1,-1)"/>`];
  el.dataset.frameRadius=r;el.dataset.frameWidth=width;el.dataset.frameHeight=height;
  el.innerHTML=`<svg class="corner-paths" viewBox="0 0 ${width} ${height}" aria-hidden="true">${paths.join('')}</svg>`;
 }
 function draw(){root.querySelectorAll('.frame-mark,.rounded-panel-frame').forEach(frame);}
 draw();window.addEventListener('resize',draw);
 window.roundedFrameReady=true;
}
