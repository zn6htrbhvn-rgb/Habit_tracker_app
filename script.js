const ICONS = ['activity', 'coffee', 'droplets', 'utensils', 'book-open', 'bed', 'dumbbell', 'bike', 'waves', 'trees', 'leaf', 'heart', 'smile', 'music', 'camera', 'brush', 'code', 'monitor', 'briefcase', 'graduation-cap', 'pill'];
const COLORS = ['#FF603E', '#00D1FF', '#7C5CFF', '#00FF85', '#FFD600', '#FF00BD'];

let habits = [];
let formState = { time: 'morning', color: COLORS[0], icon: ICONS[0] };

const getTodayKey = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function init() {
  const saved = localStorage.getItem('zenhabits_state_vanilla');
  if (saved) {
    try { habits = JSON.parse(saved).habits || []; } catch(e){}
  } else {
    habits = [
      { id: '1', name: 'Morning Meditation', iconName: 'activity', color: COLORS[1], timeOfDay: 'morning', history: {} },
      { id: '2', name: 'Daily Reading', iconName: 'book-open', color: COLORS[2], timeOfDay: 'afternoon', history: {} },
      { id: '3', name: 'Intense Workout', iconName: 'dumbbell', color: COLORS[0], timeOfDay: 'evening', history: {} },
    ];
  }
  
  setupUI();
  render();
  setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 50);
}

function save() {
  localStorage.setItem('zenhabits_state_vanilla', JSON.stringify({ habits }));
}

function setupUI() {
  document.getElementById('date-display').textContent = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  
  document.getElementById('btn-add-habit').addEventListener('click', () => {
    document.getElementById('add-panel').classList.toggle('hidden');
    renderFormSelectors();
  });
  document.getElementById('btn-cancel-add').addEventListener('click', () => {
    document.getElementById('add-panel').classList.add('hidden');
  });
  document.getElementById('btn-confirm-add').addEventListener('click', addHabit);

  document.querySelectorAll('.time-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.time-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      formState.time = btn.dataset.time;
    });
  });
}

function renderFormSelectors() {
  const cSel = document.getElementById('color-selector');
  cSel.innerHTML = COLORS.map(c => `<button class="color-btn ${c === formState.color ? 'active' : ''}" style="background-color:${c}" data-color="${c}"></button>`).join('');
  cSel.querySelectorAll('.color-btn').forEach(btn => btn.onclick = () => {
    formState.color = btn.dataset.color;
    renderFormSelectors();
  });

  const iSel = document.getElementById('icon-selector');
  iSel.innerHTML = ICONS.map(i => `<button class="icon-btn ${i === formState.icon ? 'active' : ''}" data-icon="${i}"><i data-lucide="${i}"></i></button>`).join('');
  iSel.querySelectorAll('.icon-btn').forEach(btn => btn.onclick = () => {
    formState.icon = btn.dataset.icon;
    renderFormSelectors();
    if(window.lucide) window.lucide.createIcons();
  });
}

function addHabit() {
  const nameInput = document.getElementById('habit-name');
  const name = nameInput.value.trim();
  if(!name) return;
  
  habits.push({
    id: crypto.randomUUID(),
    name,
    iconName: formState.icon,
    color: formState.color,
    timeOfDay: formState.time,
    history: {}
  });
  nameInput.value = '';
  document.getElementById('add-panel').classList.add('hidden');
  save();
  render();
}

function toggleHabit(id) {
  const today = getTodayKey();
  const habit = habits.find(h => h.id === id);
  if(habit) {
    if(habit.history[today]) delete habit.history[today];
    else habit.history[today] = true;
    save();
    render();
  }
}

function deleteHabit(id) {
  habits = habits.filter(h => h.id !== id);
  save();
  render();
}

function render() {
  const today = getTodayKey();
  const doneToday = habits.filter(h => h.history[today]).length;
  const total = habits.length;
  const percent = total > 0 ? Math.round((doneToday/total)*100) : 0;
  
  let globalStreak = 0;
  const d = new Date();
  while(true) {
    const k = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    const allDone = habits.length > 0 && habits.every(h => h.history[k]);
    if(allDone) { globalStreak++; d.setDate(d.getDate()-1); }
    else break;
  }

  document.getElementById('global-streak').textContent = globalStreak;
  document.getElementById('progress-percent').textContent = `${percent}%`;
  document.getElementById('progress-fill').style.width = `${percent}%`;
  document.getElementById('progress-count').textContent = `${doneToday} OF ${total} COMPLETED`;
  document.getElementById('progress-message').textContent = percent === 100 ? 'PEAK PERFORMANCE' : (total === 0 ? 'ADD A HABIT' : 'KEEP PUSHING');

  const hmGrid = document.getElementById('heatmap-grid');
  let hmHTML = '';
  const hd = new Date();
  for(let i=90; i>=0; i--) {
    let td = new Date(hd); td.setDate(td.getDate() - i);
    const k = `${td.getFullYear()}-${String(td.getMonth() + 1).padStart(2, '0')}-${String(td.getDate()).padStart(2, '0')}`;
    const c = habits.filter(h => h.history[k]).length;
    let l = 0;
    if(total > 0 && c > 0) {
      let r = c/total;
      if(r<=0.25) l=1; else if(r<=0.5) l=2; else if(r<=0.75) l=3; else l=4;
    }
    hmHTML += `<div class="hm-cell l-${l}" title="${c} habits completed"></div>`;
  }
  hmGrid.innerHTML = hmHTML;

  const hCont = document.getElementById('habits-container');
  hCont.innerHTML = '';
  ['morning', 'afternoon', 'evening'].forEach(slot => {
    const sectionHabits = habits.filter(h => h.timeOfDay === slot);
    if(sectionHabits.length > 0) {
      const sIcon = slot === 'morning' ? 'sun' : slot === 'afternoon' ? 'cloud' : 'moon';
      const secEl = document.createElement('div');
      secEl.className = 'time-section';
      secEl.innerHTML = `
        <div class="time-header">
          <div class="time-icon-wrap"><i data-lucide="${sIcon}"></i></div>
          <h3>${slot} Slots</h3>
          <div class="time-line"></div>
        </div>
        <div class="cards-list"></div>
      `;
      const listEl = secEl.querySelector('.cards-list');
      
      sectionHabits.forEach(h => {
        let hStreak = 0;
        let sd = new Date();
        while(true) {
          const k = `${sd.getFullYear()}-${String(sd.getMonth() + 1).padStart(2, '0')}-${String(sd.getDate()).padStart(2, '0')}`;
          if(h.history[k]) { hStreak++; sd.setDate(sd.getDate()-1); }
          else break;
        }

        const isD = !!h.history[today];
        const cardWrap = document.createElement('div');
        cardWrap.className = 'habit-card-wrapper';
        
        cardWrap.innerHTML = `
          <div class="habit-card-bg"><i data-lucide="check-circle-2"></i></div>
          <div class="habit-card ${isD ? 'done' : ''}" data-id="${h.id}">
            <div class="habit-icon" style="background-color:${h.color}10; color:${h.color}; border-color:${h.color}30">
              <i data-lucide="${h.iconName}"></i>
            </div>
            <div class="habit-info">
              <div class="habit-name">${esc(h.name)}</div>
              <div class="habit-streak"><span class="label">CURRENT STREAK</span> <i data-lucide="chevron-right"></i> <span class="value">${hStreak} DAYS</span></div>
            </div>
            <button class="habit-delete" onclick="event.stopPropagation(); window.deleteHabitGlobal('${h.id}')"><i data-lucide="trash-2"></i></button>
            <div class="habit-check"><i data-lucide="check"></i></div>
          </div>
        `;
        listEl.appendChild(cardWrap);
        
        const cardInner = cardWrap.querySelector('.habit-card');
        const cardBg = cardWrap.querySelector('.habit-card-bg');
        
        let startX = 0;
        let currentX = 0;
        let diff = 0;
        function onStart(x) {
          startX = x;
          cardInner.style.transition = 'none';
          cardBg.style.transition = 'none';
        }
        function onMove(x) {
          currentX = x;
          diff = currentX - startX;
          if(diff > 0) {
            cardInner.style.transform = `translateX(${diff}px)`;
            cardBg.style.opacity = Math.min(diff / 100, 1);
          }
        }
        function onEnd() {
          cardInner.style.transition = 'transform 0.3s cubic-bezier(0.34,1.56,0.64,1)';
          cardBg.style.transition = 'opacity 0.3s';
          if(diff > 80) { toggleHabit(h.id); }
          else { cardInner.style.transform = 'translateX(0)'; cardBg.style.opacity = '0'; }
          diff = 0;
        }

        cardInner.addEventListener('touchstart', e => onStart(e.touches[0].clientX), {passive:true});
        cardInner.addEventListener('touchmove', e => onMove(e.touches[0].clientX), {passive:true});
        cardInner.addEventListener('touchend', () => onEnd());

        let isDown = false;
        cardInner.addEventListener('mousedown', e => { isDown = true; onStart(e.clientX); });
        window.addEventListener('mousemove', e => { if(isDown) onMove(e.clientX); });
        window.addEventListener('mouseup', () => { if(isDown) { isDown = false; onEnd(); } });
      });
      
      hCont.appendChild(secEl);
    }
  });

  if(window.lucide) window.lucide.createIcons();
}

window.deleteHabitGlobal = deleteHabit;

if(document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
