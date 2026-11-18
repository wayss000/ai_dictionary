const repository = 'https://github.com/wayss000/ai_dictionary';
const latestRelease = 'https://api.github.com/repos/wayss000/ai_dictionary/releases/latest';
const packageName = 'ai_dictionary-macos.zip';

function showDownload({ label, url, size, date }) {
  const button = document.querySelector('#download');
  button.href = url;
  button.textContent = '下载 ZIP';
  const formatDate = new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai' });
  const version = document.querySelector('#version');
  version.textContent = date ? label + ' · ' + formatDate.format(new Date(date)) : label;
  version.hidden = false;
  document.querySelector('#details').textContent =
    'Universal · ZIP · ' + (size / 1024 ** 2).toFixed(1) + ' MiB';
}

async function latestDownload() {
  const response = await fetch(latestRelease, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) return null;
  const release = await response.json();
  const asset = release.assets.find((item) => item.name === packageName);
  if (!asset) return null;
  return {
    label: release.tag_name,
    url: repository + '/releases/download/' + encodeURIComponent(release.tag_name) + '/' + packageName,
    size: asset.size,
    date: release.published_at,
  };
}

async function buildDownload() {
  const response = await fetch('./build.json');
  if (!response.ok) return null;
  const build = await response.json();
  return { label: '最新构建 · ' + build.commit, url: './' + packageName, size: build.size, date: build.date };
}

async function start() {
  const [build, release] = await Promise.allSettled([buildDownload(), latestDownload()]);
  const download = release.value ?? build.value;
  if (download) showDownload(download);
}

start();
