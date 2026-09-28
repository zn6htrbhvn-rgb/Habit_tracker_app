const ICONS = ['activity', 'coffee', 'droplets', 'utensils', 'book-open', 'bed', 'dumbbell', 'bike', 'waves', 'trees', 'leaf', 'heart', 'smile', 'music', 'camera', 'brush', 'code', 'monitor', 'briefcase', 'graduation-cap', 'pill'];

// Calm-but-vivid accents that hold up on both light and dark backgrounds.
const COLORS = ['#E0643C', '#3A94D0', '#8A6FE0', '#3FA66B', '#E0A030', '#E0507F', '#22A39A', '#6B7A8F'];
const COLOR_NAMES = {
  '#E0643C': 'Terracotta', '#3A94D0': 'Sky', '#8A6FE0': 'Lavender', '#3FA66B': 'Sage',
  '#E0A030': 'Ochre', '#E0507F': 'Rose', '#22A39A': 'Teal', '#6B7A8F': 'Slate'
};
// Old neon palette -> new palette, so existing saved habits keep "their" color.
const LEGACY_COLORS = {
  '#FF603E': '#E0643C', '#00D1FF': '#3A94D0', '#7C5CFF': '#8A6FE0',
  '#00FF85': '#3FA66B', '#FFD600': '#E0A030', '#FF00BD': '#E0507F'
};

const SLOTS = ['morning', 'afternoon', 'evening'];
const SLOT_ICONS = { morning: 'sun', afternoon: 'cloud', evening: 'moon' };

const STARTERS = [
  { name: 'Drink a glass of water', iconName: 'droplets', color: '#3A94D0', timeOfDay: 'morning' },
  { name: 'Stretch for 5 minutes', iconName: 'activity', color: '#3FA66B', timeOfDay: 'morning' },
  { name: 'Take a short walk', iconName: 'trees', color: '#22A39A', timeOfDay: 'afternoon' },
  { name: 'Read 10 pages', iconName: 'book-open', color: '#8A6FE0', timeOfDay: 'evening' },
  { name: 'Screens off by 10pm', iconName: 'bed', color: '#6B7A8F', timeOfDay: 'evening' }
];

const STORAGE_KEY = 'zenhabits_state_vanilla';
const THEME_KEY = 'zenhabit_theme';
const HINT_KEY = 'zenhabit_swipe_hint_dismissed';
const SWIPE_THRESHOLD = 80;
const LONG_PRESS_MS = 500;

let habits = [];
let formState = { time: 'morning', color: COLORS[0], icon: ICONS[0] };
let heatmapFilter = 'all';
let menuHabitId = null;
let lastPercent = null;
let toastTimer = null;
let undoAction = null;

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const dateKey = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const getTodayKey = () => dateKey(new Date());

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const uid = () => (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : `h-${Date.now()}-${Math.random().toString(36).slice(2)}`;
const $ = id => document.getElementById(id);
const refreshIcons = () => { if (window.lucide) window.lucide.createIcons(); };

function storageGet(key) {
  try { return localStorage.getItem(key); } catch (e) { return null; }
}
function storageSet(key, value) {
  try { localStorage.setItem(key, value); } catch (e) {}
}

function init() {
  const saved = storageGet(STORAGE_KEY);
  if (saved) {
    try { habits = JSON.parse(saved).habits || []; } catch (e) {}
    habits.forEach(h => { if (LEGACY_COLORS[h.color]) h.color = LEGACY_COLORS[h.color]; });
  } else {
    habits = [
      { id: '1', name: 'Morning Meditation', iconName: 'activity', color: COLORS[1], timeOfDay: 'morning', history: {} },
      { id: '2', name: 'Daily Reading', iconName: 'book-open', color: COLORS[2], timeOfDay: 'afternoon', history: {} },
      { id: '3', name: 'Intense Workout', iconName: 'dumbbell', color: COLORS[0], timeOfDay: 'evening', history: {} },
    ];
  }

  setupUI();
  render();
  maybeShowSwipeHint();
  setTimeout(refreshIcons, 50);
}

function save() {
  storageSet(STORAGE_KEY, JSON.stringify({ habits }));
}

/* ---------------------------------------------------------------- Theme */

function effectiveTheme() {
  const forced = document.documentElement.getAttribute('data-theme');
  if (forced) return forced;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function toggleTheme() {
  const next = effectiveTheme() === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  storageSet(THEME_KEY, next);
  updateThemeButton();
}

function updateThemeButton() {
  const dark = effectiveTheme() === 'dark';
  $('btn-theme').setAttribute('aria-label', dark ? 'Switch to light mode' : 'Switch to dark mode');
}

/* ---------------------------------------------------------------- Setup */

function setupUI() {
  $('date-display').textContent = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });

  $('btn-theme').addEventListener('click', toggleTheme);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change', updateThemeButton);
  updateThemeButton();

  $('btn-add-habit').addEventListener('click', () => openAddPanel());
  $('btn-cancel-add').addEventListener('click', () => closeSheet($('add-panel')));
  $('btn-confirm-add').addEventListener('click', addHabit);

  const nameInput = $('habit-name');
  nameInput.addEventListener('input', () => {
    setNameError(false);
    updatePreview();
  });
  nameInput.addEventListener('keydown', e => { if (e.key === 'Enter') addHabit(); });

  document.querySelectorAll('.time-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      formState.time = btn.dataset.time;
      syncFormSelection();
    });
  });

  // Anything with data-close-sheet closes its sheet (backdrop, X, Cancel).
  document.querySelectorAll('[data-close-sheet]').forEach(el => {
    el.addEventListener('click', () => closeSheet(el.closest('.sheet')));
  });
  document.addEventListener('keydown', onSheetKeydown);

  $('menu-toggle').addEventListener('click', () => {
    const id = menuHabitId;
    closeSheet($('habit-menu'), false);
    if (id) toggleHabit(id);
  });
  $('menu-delete').addEventListener('click', () => {
    const id = menuHabitId;
    closeSheet($('habit-menu'), false);
    if (id) deleteHabit(id);
  });

  $('toast-undo').addEventListener('click', () => {
    if (undoAction) undoAction();
    hideToast();
  });

  $('btn-dismiss-hint').addEventListener('click', dismissSwipeHint);

  // Event delegation for habit cards (survives re-renders, no listener leaks).
  const container = $('habits-container');
  container.addEventListener('click', onContainerClick);
  container.addEventListener('contextmenu', e => {
    const card = e.target.closest('.habit-card');
    if (!card) return;
    e.preventDefault();
    openMenu(card.dataset.id, card.querySelector('.habit-more'));
  });
  container.addEventListener('pointerdown', onPointerDown);

  $('heatmap-filter').addEventListener('click', e => {
    const chip = e.target.closest('.hm-chip');
    if (!chip) return;
    heatmapFilter = chip.dataset.habit;
    renderHeatmap();
  });
}

function onContainerClick(e) {
  if (suppressNextClick) { suppressNextClick = false; e.preventDefault(); return; }

  const starter = e.target.closest('.starter-chip');
  if (starter) {
    const s = STARTERS[+starter.dataset.starter];
    if (s) createHabit(s);
    return;
  }
  if (e.target.closest('.btn-empty-add')) { openAddPanel(e.target.closest('button')); return; }

  const card = e.target.closest('.habit-card');
  if (!card) return;
  if (e.target.closest('.habit-check')) { toggleHabit(card.dataset.id); return; }
  if (e.target.closest('.habit-more')) { openMenu(card.dataset.id, e.target.closest('.habit-more')); }
}

/* ------------------------------------------------ Gestures (swipe / long-press) */

let gesture = null;
let suppressNextClick = false;

function onPointerDown(e) {
  if (e.button !== 0) return;
  const card = e.target.closest('.habit-card');
  if (!card) return;
  const wrap = card.parentElement;
  wrap.classList.remove('peek');
  // Stop a mouse drag from selecting text across the page (buttons keep default focus behavior).
  if (e.pointerType === 'mouse' && !e.target.closest('button')) e.preventDefault();

  gesture = {
    id: e.pointerId, card, wrap, bg: wrap.querySelector('.habit-card-bg'),
    startX: e.clientX, startY: e.clientY, dx: 0, dragging: false, done: false,
    // Long-press is for touch/pen; mouse users get right-click and the "..." button.
    timer: e.pointerType === 'mouse' ? null : setTimeout(() => onLongPress(), LONG_PRESS_MS)
  };
  if (gesture.timer) wrap.classList.add('pressing');

  card.addEventListener('pointermove', onPointerMove);
  card.addEventListener('pointerup', onPointerEnd);
  card.addEventListener('pointercancel', onPointerEnd);
}

function onLongPress() {
  if (!gesture) return;
  const { card, wrap } = gesture;
  gesture.done = true;
  wrap.classList.remove('pressing');
  suppressNextClick = true;
  if (navigator.vibrate) navigator.vibrate(12);
  openMenu(card.dataset.id, card.querySelector('.habit-more'));
}

function onPointerMove(e) {
  const g = gesture;
  if (!g || e.pointerId !== g.id || g.done) return;
  const mx = e.clientX - g.startX;
  const my = e.clientY - g.startY;

  if (!g.dragging) {
    if (Math.abs(mx) < 8 && Math.abs(my) < 8) return;
    clearTimeout(g.timer);
    g.wrap.classList.remove('pressing');
    // Only a mostly-horizontal rightward drag becomes a swipe; anything else is a scroll.
    if (mx > 0 && Math.abs(mx) > Math.abs(my) * 1.2) {
      g.dragging = true;
      try { g.card.setPointerCapture(g.id); } catch (err) {}
      g.card.style.transition = 'none';
      g.bg.style.transition = 'none';
      g.wrap.classList.add('swiping');
    } else {
      endGesture();
      return;
    }
  }

  g.dx = Math.max(0, mx);
  // Rubber-band past the threshold so it feels physical.
  const shown = g.dx > SWIPE_THRESHOLD ? SWIPE_THRESHOLD + (g.dx - SWIPE_THRESHOLD) * 0.35 : g.dx;
  g.card.style.transform = `translateX(${shown}px)`;
  g.bg.style.opacity = Math.min(g.dx / SWIPE_THRESHOLD, 1);
  const armed = g.dx > SWIPE_THRESHOLD;
  if (armed !== g.wrap.classList.contains('armed')) {
    g.wrap.classList.toggle('armed', armed);
    if (armed && navigator.vibrate) navigator.vibrate(8);
  }
}

function onPointerEnd(e) {
  const g = gesture;
  if (!g || e.pointerId !== g.id) return;
  if (g.dragging) {
    suppressNextClick = true;
    setTimeout(() => { suppressNextClick = false; }, 0);
    const complete = g.dx > SWIPE_THRESHOLD;
    const { card, bg, wrap } = g;
    card.style.transition = '';
    bg.style.transition = '';
    card.style.transform = 'translateX(0)';
    bg.style.opacity = '0';
    wrap.classList.remove('swiping', 'armed');
    if (complete) setTimeout(() => toggleHabit(card.dataset.id), reducedMotion() ? 0 : 160);
  } else if (g.done) {
    // Long-press already handled; swallow the click that follows pointerup.
    setTimeout(() => { suppressNextClick = false; }, 350);
  }
  endGesture();
}

function endGesture() {
  const g = gesture;
  if (!g) return;
  clearTimeout(g.timer);
  g.wrap.classList.remove('pressing');
  g.card.removeEventListener('pointermove', onPointerMove);
  g.card.removeEventListener('pointerup', onPointerEnd);
  g.card.removeEventListener('pointercancel', onPointerEnd);
  gesture = null;
}

/* --------------------------------------------------------------- Sheets */

let openSheetEl = null;
let sheetReturnFocus = null;

function openSheet(sheet, returnFocus, focusEl) {
  if (openSheetEl && openSheetEl !== sheet) closeSheet(openSheetEl, false);
  openSheetEl = sheet;
  sheetReturnFocus = returnFocus || document.activeElement;
  sheet.classList.remove('hidden');
  sheet.setAttribute('aria-hidden', 'false');
  document.body.classList.add('sheet-open');
  const target = focusEl || sheet.querySelector('button, input');
  // Wait a frame so the slide-in isn't interrupted by focus scrolling.
  requestAnimationFrame(() => target && target.focus({ preventScroll: true }));
}

function closeSheet(sheet, restoreFocus = true) {
  if (!sheet || sheet.classList.contains('hidden')) return;
  sheet.classList.add('hidden');
  sheet.setAttribute('aria-hidden', 'true');
  document.body.classList.remove('sheet-open');
  if (openSheetEl === sheet) openSheetEl = null;
  if (restoreFocus && sheetReturnFocus && document.contains(sheetReturnFocus)) sheetReturnFocus.focus();
}

function onSheetKeydown(e) {
  if (!openSheetEl) return;
  if (e.key === 'Escape') { closeSheet(openSheetEl); return; }
  if (e.key !== 'Tab') return;
  // Simple focus trap.
  const items = [...openSheetEl.querySelectorAll('button, input')].filter(el => el.offsetParent !== null);
  if (!items.length) return;
  const first = items[0], last = items[items.length - 1];
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
}

/* ------------------------------------------------------------- Add form */

function openAddPanel(trigger) {
  $('habit-name').value = '';
  setNameError(false);
  renderFormSelectors();
  openSheet($('add-panel'), trigger || $('btn-add-habit'), $('habit-name'));
}

let selectorsBuilt = false;
function renderFormSelectors() {
  if (!selectorsBuilt) {
    const cSel = $('color-selector');
    cSel.innerHTML = COLORS.map(c => `<button type="button" class="color-btn" style="--habit:${c}" data-color="${c}" aria-label="${COLOR_NAMES[c]}"></button>`).join('');
    cSel.querySelectorAll('.color-btn').forEach(btn => btn.onclick = () => {
      formState.color = btn.dataset.color;
      syncFormSelection();
    });

    const iSel = $('icon-selector');
    iSel.innerHTML = ICONS.map(i => `<button type="button" class="icon-btn" data-icon="${i}" aria-label="${i.replace(/-/g, ' ')}"><i data-lucide="${i}"></i></button>`).join('');
    iSel.querySelectorAll('.icon-btn').forEach(btn => btn.onclick = () => {
      formState.icon = btn.dataset.icon;
      syncFormSelection();
    });
    selectorsBuilt = true;
    refreshIcons();
  }
  syncFormSelection();
}

function syncFormSelection() {
  document.querySelectorAll('.time-btn').forEach(b => {
    const on = b.dataset.time === formState.time;
    b.classList.toggle('active', on);
    b.setAttribute('aria-pressed', on);
  });
  document.querySelectorAll('.color-btn').forEach(b => {
    const on = b.dataset.color === formState.color;
    b.classList.toggle('active', on);
    b.setAttribute('aria-pressed', on);
  });
  document.querySelectorAll('.icon-btn').forEach(b => {
    const on = b.dataset.icon === formState.icon;
    b.classList.toggle('active', on);
    b.setAttribute('aria-pressed', on);
  });
  $('add-panel').querySelector('.sheet-card').style.setProperty('--habit', formState.color);
  updatePreview();
}

function updatePreview() {
  const name = $('habit-name').value.trim();
  const nameEl = $('preview-name');
  nameEl.textContent = name || 'Your new habit';
  nameEl.classList.toggle('placeholder', !name);
  $('preview-meta').textContent = formState.time;
  const icon = $('preview-icon');
  if (icon.dataset.icon !== formState.icon) {
    icon.dataset.icon = formState.icon;
    icon.innerHTML = `<i data-lucide="${formState.icon}"></i>`;
    refreshIcons();
  }
}

function setNameError(on) {
  const input = $('habit-name');
  input.setAttribute('aria-invalid', on ? 'true' : 'false');
  $('habit-name-error').classList.toggle('hidden', !on);
}

function addHabit() {
  const nameInput = $('habit-name');
  const name = nameInput.value.trim();
  if (!name) {
    // Restart the shake animation if it was already invalid.
    setNameError(false);
    void nameInput.offsetWidth;
    setNameError(true);
    nameInput.focus();
    return;
  }
  nameInput.value = '';
  closeSheet($('add-panel'));
  createHabit({ name, iconName: formState.icon, color: formState.color, timeOfDay: formState.time });
}

function createHabit({ name, iconName, color, timeOfDay }) {
  const habit = { id: uid(), name, iconName, color, timeOfDay, history: {} };
  habits.push(habit);
  save();
  render();
  showToast(`Added “${name}”`);
}

/* ----------------------------------------------------------- Habit actions */

function toggleHabit(id) {
  const today = getTodayKey();
  const habit = habits.find(h => h.id === id);
  if (habit) {
    if (habit.history[today]) delete habit.history[today];
    else habit.history[today] = true;
    save();
    render({ justToggled: id });
  }
}

function deleteHabit(id) {
  const index = habits.findIndex(h => h.id === id);
  if (index === -1) return;
  const [removed] = habits.splice(index, 1);
  if (heatmapFilter === id) heatmapFilter = 'all';
  save();
  render();
  showToast(`Deleted “${removed.name}”`, () => {
    habits.splice(Math.min(index, habits.length), 0, removed);
    save();
    render();
  });
}

function openMenu(id, trigger) {
  const habit = habits.find(h => h.id === id);
  if (!habit) return;
  menuHabitId = id;
  const done = !!habit.history[getTodayKey()];
  $('menu-title').textContent = habit.name;
  $('menu-toggle-label').textContent = done ? 'Mark not done today' : 'Mark done today';
  const head = $('habit-menu').querySelector('.menu-head');
  head.style.setProperty('--habit', habit.color);
  $('menu-icon').innerHTML = `<i data-lucide="${habit.iconName}"></i>`;
  refreshIcons();
  openSheet($('habit-menu'), trigger, $('menu-toggle'));
}

/* ------------------------------------------------------------------ Toast */

function showToast(message, onUndo) {
  clearTimeout(toastTimer);
  const toast = $('toast');
  $('toast-msg').textContent = message;
  undoAction = onUndo || null;
  toast.classList.toggle('no-undo', !onUndo);
  toast.classList.remove('hidden');
  toastTimer = setTimeout(hideToast, onUndo ? 6000 : 2500);
}

function hideToast() {
  clearTimeout(toastTimer);
  $('toast').classList.add('hidden');
  undoAction = null;
}

/* ------------------------------------------------------------ Swipe hint */

function maybeShowSwipeHint() {
  if (storageGet(HINT_KEY) || habits.length === 0) return;
  $('swipe-hint').classList.remove('hidden');
  if (reducedMotion()) return;
  const first = document.querySelector('.habit-card-wrapper');
  if (first) {
    first.classList.add('peek');
    first.addEventListener('animationend', () => first.classList.remove('peek'), { once: true });
  }
}

function dismissSwipeHint() {
  storageSet(HINT_KEY, '1');
  $('swipe-hint').classList.add('hidden');
}

/* ---------------------------------------------------------------- Streaks */

// A streak stays alive through today until the day is over: if today isn't
// checked yet, count back from yesterday instead of showing 0.
function countStreak(isDone) {
  const d = new Date();
  if (!isDone(dateKey(d))) d.setDate(d.getDate() - 1);
  let n = 0;
  while (isDone(dateKey(d))) { n++; d.setDate(d.getDate() - 1); }
  return n;
}

/* ----------------------------------------------------------------- Render */

function render({ justToggled } = {}) {
  const today = getTodayKey();
  const doneToday = habits.filter(h => h.history[today]).length;
  const total = habits.length;
  const percent = total > 0 ? Math.round((doneToday / total) * 100) : 0;

  const globalStreak = countStreak(k => habits.length > 0 && habits.every(h => h.history[k]));

  $('global-streak').textContent = globalStreak;
  $('streak-pill').classList.toggle('is-active', globalStreak > 0);
  $('streak-pill').title = `${globalStreak}-day streak with every habit done`;

  $('progress-percent').textContent = `${percent}%`;
  $('progress-fill').style.width = `${percent}%`;
  $('progress-track').setAttribute('aria-valuenow', percent);
  $('progress-count').textContent = `${doneToday} of ${total} completed`;
  $('progress-message').textContent =
    total === 0 ? 'Add a habit to begin' :
    percent === 100 ? 'All done. Beautifully done.' :
    percent >= 75 ? 'Almost there' :
    percent > 0 ? 'Nice, keep going' : 'A gentle start';
  $('progress-section').classList.toggle('complete', percent === 100);

  if (justToggled && percent === 100 && lastPercent !== null && lastPercent < 100) celebrate();
  lastPercent = percent;

  renderHabits(today);
  renderHeatmap();
  refreshIcons();

  if (justToggled) {
    const card = document.querySelector(`.habit-card[data-id="${CSS.escape(justToggled)}"]`);
    if (card && card.classList.contains('done')) {
      card.classList.add('just-done');
      if (navigator.vibrate) navigator.vibrate(10);
    }
  }
}

function renderHabits(today) {
  const hCont = $('habits-container');
  hCont.innerHTML = '';

  if (habits.length === 0) {
    $('swipe-hint').classList.add('hidden');
    hCont.innerHTML = `
      <div class="empty-state">
        <div class="empty-art"><i data-lucide="sprout"></i></div>
        <h3>A clean slate</h3>
        <p>Nothing to track yet, and that's okay. The best habits start tiny. Pick one to begin:</p>
        <div class="starter-list">
          ${STARTERS.map((s, i) => `
            <button type="button" class="starter-chip" data-starter="${i}" style="--habit:${s.color}">
              <i data-lucide="${s.iconName}"></i>${esc(s.name)}
            </button>`).join('')}
        </div>
        <button type="button" class="btn-primary btn-empty-add"><i data-lucide="plus"></i> Create your own</button>
      </div>`;
    return;
  }

  SLOTS.forEach(slot => {
    const sectionHabits = habits.filter(h => h.timeOfDay === slot);
    if (sectionHabits.length === 0) return;

    const doneCount = sectionHabits.filter(h => h.history[today]).length;
    const secEl = document.createElement('section');
    secEl.className = 'time-section';
    secEl.setAttribute('aria-label', slot);
    secEl.innerHTML = `
      <div class="time-header">
        <div class="time-icon-wrap"><i data-lucide="${SLOT_ICONS[slot]}"></i></div>
        <h3>${slot}</h3>
        <span class="time-count">${doneCount}/${sectionHabits.length}</span>
        <div class="time-line"></div>
      </div>
      <div class="cards-list"></div>
    `;
    const listEl = secEl.querySelector('.cards-list');

    sectionHabits.forEach(h => {
      const hStreak = countStreak(k => !!h.history[k]);
      const isD = !!h.history[today];
      const name = esc(h.name);
      const streakText = hStreak > 0 ? `${hStreak}-day streak` : 'Start a streak today';

      const cardWrap = document.createElement('div');
      cardWrap.className = 'habit-card-wrapper';
      cardWrap.style.setProperty('--habit', h.color);
      cardWrap.innerHTML = `
        <div class="habit-card-bg" aria-hidden="true"><i data-lucide="${isD ? 'undo-2' : 'check-circle-2'}"></i>${isD ? 'Undo' : 'Done'}</div>
        <div class="habit-card ${isD ? 'done' : ''}" data-id="${esc(h.id)}">
          <div class="habit-icon" aria-hidden="true"><i data-lucide="${esc(h.iconName)}"></i></div>
          <div class="habit-info">
            <div class="habit-name">${name}</div>
            <div class="habit-streak ${hStreak > 0 ? 'on' : ''}"><i data-lucide="flame"></i><span class="value">${streakText}</span></div>
          </div>
          <button type="button" class="habit-more" aria-label="More options for ${name}" aria-haspopup="dialog"><i data-lucide="more-horizontal"></i></button>
          <button type="button" class="habit-check" aria-pressed="${isD}" aria-label="${isD ? 'Completed' : 'Complete'}: ${name}"><i data-lucide="check"></i></button>
        </div>
      `;
      listEl.appendChild(cardWrap);
    });

    hCont.appendChild(secEl);
  });
}

function renderHeatmap() {
  if (heatmapFilter !== 'all' && !habits.some(h => h.id === heatmapFilter)) heatmapFilter = 'all';
  const selected = habits.find(h => h.id === heatmapFilter);
  const list = selected ? [selected] : habits;
  const total = list.length;

  // Filter chips
  const filter = $('heatmap-filter');
  filter.hidden = habits.length < 2;
  filter.innerHTML = [
    `<button type="button" class="hm-chip ${heatmapFilter === 'all' ? 'active' : ''}" data-habit="all" aria-pressed="${heatmapFilter === 'all'}">All habits</button>`,
    ...habits.map(h => `<button type="button" class="hm-chip ${heatmapFilter === h.id ? 'active' : ''}" data-habit="${esc(h.id)}" style="--habit:${h.color}" aria-pressed="${heatmapFilter === h.id}">${esc(h.name)}</button>`)
  ].join('');

  $('heatmap-section').style.setProperty('--hm-color', selected ? selected.color : 'var(--accent)');

  const hmGrid = $('heatmap-grid');
  let hmHTML = '';
  let activeDays = 0;
  const hd = new Date();
  for (let i = 90; i >= 0; i--) {
    const td = new Date(hd); td.setDate(td.getDate() - i);
    const k = dateKey(td);
    const c = list.filter(h => h.history[k]).length;
    let l = 0;
    if (total > 0 && c > 0) {
      activeDays++;
      const r = c / total;
      if (r <= 0.25) l = 1; else if (r <= 0.5) l = 2; else if (r <= 0.75) l = 3; else l = 4;
    }
    const label = td.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    const tip = selected ? `${label}: ${c ? 'done' : 'not done'}` : `${label}: ${c} of ${total} habits`;
    hmHTML += `<div class="hm-cell l-${l}${i === 0 ? ' today' : ''}" title="${esc(tip)}"></div>`;
  }
  hmGrid.innerHTML = hmHTML;

  const who = selected ? esc(selected.name) : 'all habits';
  $('hm-summary').innerHTML = `${activeDays} active ${activeDays === 1 ? 'day' : 'days'} · ${who}`;
  hmGrid.setAttribute('aria-label', `Heatmap of the last 90 days for ${selected ? selected.name : 'all habits'}: ${activeDays} active days`);
}

/* ------------------------------------------------------------ Celebration */

function celebrate() {
  const section = $('progress-section');
  section.classList.remove('celebrate');
  void section.offsetWidth;
  section.classList.add('celebrate');
  showToast('Every habit done today 🌿');
  if (navigator.vibrate) navigator.vibrate([12, 60, 12]);
  if (reducedMotion()) return;

  const layer = $('celebration');
  const rect = section.getBoundingClientRect();
  const originY = Math.max(0, rect.top + rect.height / 2);
  const palette = habits.length ? [...new Set(habits.map(h => h.color))] : COLORS;
  const frag = document.createDocumentFragment();
  for (let i = 0; i < 48; i++) {
    const p = document.createElement('span');
    p.className = 'confetti' + (Math.random() < 0.35 ? ' round' : '');
    const size = 6 + Math.random() * 6;
    p.style.cssText = `
      --c:${palette[i % palette.length]};
      --x0:${45 + Math.random() * 10}%;
      --y:${originY}px;
      --w:${size}px; --h:${size * (1 + Math.random() * 0.6)}px;
      --dx:${(Math.random() - 0.5) * 90}vw;
      --up:${-60 - Math.random() * 160}px;
      --r:${(Math.random() - 0.5) * 900}deg;
      --d:${1100 + Math.random() * 800}ms;
      animation-delay:${Math.random() * 120}ms;`;
    frag.appendChild(p);
  }
  layer.appendChild(frag);
  setTimeout(() => { layer.innerHTML = ''; }, 2400);
}

// Kept for backwards compatibility with anything that still calls it.
window.deleteHabitGlobal = deleteHabit;

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
