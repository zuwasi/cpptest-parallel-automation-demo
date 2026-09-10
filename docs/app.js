const projectOrder = ['project-alpha', 'project-beta', 'project-gamma'];
const replayMetadata = {
  'project-alpha': {
    id: 'project-alpha', name: 'Flight Sensor Statistics', standard: 'MISRA C 2023', config: 'MISRA C 2023 (MISRA C 2012)', accent: 'cyan',
    requirements: ['MISRA 15.6: compound statements', 'MISRA 10.4: essential types', 'MISRA 12.2: arithmetic range'],
    expectedIssues: ['Missing braces', 'Signed/unsigned conversion', 'Narrow arithmetic accumulator']
  },
  'project-beta': {
    id: 'project-beta', name: 'Audit Text Processor', standard: 'Flow Analysis', config: 'Flow Analysis Standard', accent: 'amber',
    requirements: ['No use before initialization', 'Validate before dereference', 'Close resources on every path'],
    expectedIssues: ['Uninitialized variable', 'Possible null dereference', 'File resource leak']
  },
  'project-gamma': {
    id: 'project-gamma', name: 'Network Command Queue', standard: 'CERT C', config: 'SEI CERT C Rules', accent: 'violet',
    requirements: ['STR31-C: sufficient string storage', 'INT32-C: prevent signed overflow', 'ERR33-C: handle library errors'],
    expectedIssues: ['Unbounded strcpy', 'Signed integer overflow', 'Unchecked library result']
  }
};

const replayFindings = {
  'project-alpha': ['MISRAC2012-DIR_4_6-b', 'MISRAC2012-DIR_4_6-d', 'MISRAC2012-RULE_10_3-b', 'MISRAC2012-RULE_10_4-a', 'MISRAC2012-RULE_12_1-a', 'MISRAC2012-RULE_15_5-a', 'MISRAC2012-RULE_15_6-b', 'MISRAC2012-RULE_17_7-a', 'MISRAC2012-RULE_21_6-a'],
  'project-beta': ['BD-PB-NOTINIT', 'BD-RES-LEAKS'],
  'project-gamma': ['CERT_C-INT32-a', 'CERT_C-POS54-a', 'CERT_C-STR31-c', 'CERT_C-STR31-e']
};
const replayResults = {
  'project-alpha': { rules: 385, findings: 26 },
  'project-beta': { rules: 105, findings: 2 },
  'project-gamma': { rules: 193, findings: 4 }
};

let mode = 'replay';
let replayTimer = null;
let replayStarted = null;
let currentState = makeReplayState(false);

const grid = document.querySelector('#projectGrid');
const template = document.querySelector('#projectTemplate');
const runButton = document.querySelector('#runButton');
const modeBadge = document.querySelector('#modeBadge');

function makeReplayState(running) {
  const projects = {};
  for (const id of projectOrder) {
    projects[id] = {
      ...replayMetadata[id], status: running ? 'running' : 'idle', elapsedSeconds: 0, pid: null,
      license: running ? 'activating' : 'waiting', filesTotal: 3, filesChecked: 0, linesChecked: 0,
      rulesConfigured: 0, rulesExecuted: null, findings: 0, detectedIssues: [], reportUrl: null,
      console: [`[${id}] Ready. Configuration: ${replayMetadata[id].config}`]
    };
  }
  return {
    mode: 'replay', running, runStartedAt: running ? Date.now() / 1000 : null,
    runtime: {
      containerized: true, containerId: 'public-replay', platform: 'Linux',
      engine: 'C++test Pro 2025.1', toolchain: 'GCC 6.3 / CMake'
    }, projects
  };
}

function formatTime(seconds) {
  const value = Math.max(0, Math.floor(seconds || 0));
  return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`;
}

function render(state) {
  currentState = state;
  grid.innerHTML = '';
  let validLicenses = 0;
  let runningCount = 0;
  let maxElapsed = 0;

  for (const id of projectOrder) {
    const project = state.projects[id];
    const fragment = template.content.cloneNode(true);
    const card = fragment.querySelector('.project-card');
    card.style.setProperty('--accent', `var(--${project.accent})`);
    fragment.querySelector('.project-id').textContent = `${project.id} · ${project.config}`;
    fragment.querySelector('.project-name').textContent = project.name;
    fragment.querySelector('.standard').textContent = project.standard;
    const status = fragment.querySelector('.status-pill');
    status.textContent = project.status;
    status.classList.add(project.status);
    fragment.querySelector('.elapsed').textContent = formatTime(project.elapsedSeconds);
    const filesChecked = project.filesTotal ? Math.min(project.filesChecked, project.filesTotal) : project.filesChecked;
    fragment.querySelector('.files').textContent = `${filesChecked} / ${project.filesTotal || '?'}`;
    fragment.querySelector('.rules').textContent = project.rulesConfigured || '—';
    fragment.querySelector('.findings').textContent = project.findings;
    fragment.querySelector('.pid').textContent = mode === 'replay' ? 'replay' : (project.pid ? `PID ${project.pid}` : 'waiting');

    const progress = fragment.querySelector('.scan-progress span');
    if (project.status === 'running' && !project.filesChecked) progress.classList.add('indeterminate');
    else progress.style.width = `${project.status === 'completed' ? 100 : Math.min(100, project.filesTotal ? project.filesChecked / project.filesTotal * 100 : 0)}%`;

    const licenseDot = fragment.querySelector('.license-dot');
    licenseDot.classList.add(project.license);
    fragment.querySelector('.license-text').textContent = `Automation license ${project.license}`;
    if (project.license === 'valid') validLicenses += 1;
    if (project.status === 'running') runningCount += 1;
    maxElapsed = Math.max(maxElapsed, project.elapsedSeconds || 0);

    const requirements = fragment.querySelector('.requirements');
    for (const requirement of project.requirements) {
      const item = document.createElement('li');
      item.textContent = requirement;
      requirements.append(item);
    }
    const issues = fragment.querySelector('.expected-issues');
    for (const issue of project.expectedIssues) {
      const chip = document.createElement('span');
      chip.className = 'issue-chip';
      chip.textContent = issue;
      issues.append(chip);
    }

    const detected = fragment.querySelector('.detected');
    if (project.detectedIssues?.length) {
      const ruleIds = project.detectedIssues.slice(0, 5).map(issue => issue.id).join(', ');
      const remaining = project.detectedIssues.length > 5 ? ` +${project.detectedIssues.length - 5} more` : '';
      detected.textContent = `${project.detectedIssues.length} rule types in report: ${ruleIds}${remaining}`;
      if (project.rulesExecuted === 0) {
        detected.textContent += ' · CLI phase-header count differs';
        detected.classList.add('warning');
      }
    } else if (project.status === 'completed' && project.rulesExecuted === 0) {
      detected.textContent = 'Configuration warning: engine executed zero rules';
      detected.classList.add('warning');
    } else {
      detected.textContent = project.status === 'completed' ? 'No findings detected' : 'Awaiting scanner results';
    }

    const consoleElement = fragment.querySelector('.console');
    consoleElement.textContent = project.console.slice(-9).join('\n');
    const report = fragment.querySelector('.report-link');
    if (project.reportUrl && mode === 'live') report.href = project.reportUrl;
    else report.removeAttribute('href');
    grid.append(fragment);
  }

  document.querySelector('#licenseSessions').textContent = `${validLicenses} / 3 valid`;
  document.querySelector('#totalElapsed').textContent = formatTime(maxElapsed);
  document.querySelector('#engine').textContent = state.runtime?.engine || 'C++test Pro';
  document.querySelector('#toolchain').textContent = state.runtime?.toolchain || 'GCC / CMake';
  document.querySelector('#runtime').textContent = state.runtime?.containerized
    ? `Docker · ${state.runtime.containerId.slice(0, 12)}`
    : `${state.runtime?.platform || 'Host'} · 3 workspaces`;
  document.querySelector('#pulse').classList.toggle('running', state.running);
  document.querySelector('#parallelStatus').textContent = state.running ? `${runningCount} scans executing concurrently` : 'One server, three isolated scans';
  document.querySelector('#statusDetail').textContent = state.running ? 'Independent processes, workspaces, configurations and reports' : 'Ready for the next parallel run';
  runButton.disabled = state.running;
  runButton.textContent = state.running ? 'Parallel scan running…' : (mode === 'live' ? 'Start parallel scan' : 'Replay parallel scan');
}

function updateReplay() {
  const elapsed = (Date.now() - replayStarted) / 1000;
  const eventLines = {
    'project-alpha': ['Loading MISRA C configuration…', 'Automation feature: License is valid', 'Importing GCC build data…', 'Checking statistics.c…', 'MISRA-C-15.6: missing compound statement', 'MISRA-C-10.4: essential type mismatch'],
    'project-beta': ['Loading Flow Analysis configuration…', 'Automation feature: License is valid', 'Building control flow graph…', 'Checking text_utils.c…', 'BD-PB-NOTINIT: possible use before initialization', 'BD-RES-LEAKS: resource may not be closed'],
    'project-gamma': ['Loading SEI CERT C configuration…', 'Automation feature: License is valid', 'Indexing command queue…', 'Checking main.c…', 'CERT_C-STR31-a: destination may be too small', 'CERT_C-INT32-a: signed addition may overflow']
  };

  for (const id of projectOrder) {
    const project = currentState.projects[id];
    project.elapsedSeconds = elapsed;
    project.license = elapsed > 1.2 ? 'valid' : 'activating';
    const lines = eventLines[id].slice(0, Math.min(eventLines[id].length, Math.floor(elapsed / 1.1) + 1));
    project.console = lines.map(line => `[${new Date().toLocaleTimeString()}] [${id}] ${line}`);
    project.filesChecked = Math.min(3, Math.floor(elapsed / 2));
    project.rulesConfigured = replayResults[id].rules;
    if (elapsed >= 7) {
      project.status = 'completed';
      project.filesChecked = 3;
      project.detectedIssues = replayFindings[id].map(ruleId => ({ id: ruleId }));
      project.findings = replayResults[id].findings;
      project.rulesExecuted = project.rulesConfigured;
    }
  }
  currentState.running = elapsed < 7;
  render(currentState);
  if (!currentState.running) clearInterval(replayTimer);
}

async function startRun() {
  if (mode === 'live') {
    const response = await fetch('api/run', { method: 'POST' });
    if (!response.ok) throw new Error(await response.text());
    return;
  }
  clearInterval(replayTimer);
  currentState = makeReplayState(true);
  replayStarted = Date.now();
  render(currentState);
  replayTimer = setInterval(updateReplay, 350);
}

async function connect() {
  try {
    const response = await fetch('api/status', { cache: 'no-store' });
    if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) throw new Error('No live API');
    mode = 'live';
    modeBadge.textContent = 'LIVE SERVER';
    modeBadge.className = 'mode-badge live';
    document.querySelector('#dataNotice').textContent = 'Observed scanner output only. DTP report publishing is disabled.';
    const poll = async () => {
      try {
        const latest = await fetch('api/status', { cache: 'no-store' }).then(result => result.json());
        render(latest);
      } catch (error) {
        console.error(error);
      }
    };
    await poll();
    setInterval(poll, 700);
  } catch {
    mode = 'replay';
    modeBadge.textContent = 'PUBLIC REPLAY';
    modeBadge.className = 'mode-badge replay';
    render(currentState);
    setTimeout(() => startRun().catch(error => console.error(error)), 500);
  }
  runButton.disabled = false;
}

runButton.addEventListener('click', () => startRun().catch(error => alert(error.message)));
connect();
