import { invoke } from "@tauri-apps/api/core";
import "./styles.css";

type RoutingMode = "rule" | "global" | "direct";
type CoreStatus = {
  running: boolean;
  pid: number | null;
  message: string;
};
type SystemProxyStatus = {
  enabled: boolean;
  managedByViasix: boolean;
  endpoint: { host: string; port: number } | null;
  message: string;
};
type ExitIpResult = {
  ip: string;
  family: string;
  source: string;
  message: string;
};

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) {
  throw new Error("#app missing");
}

app.innerHTML = `
  <main class="shell">
    <header>
      <h1>ViaSix <span class="badge">Windows MVP</span></h1>
      <p class="muted">IPv6-first · 契约投影 · 用户态 Mihomo · 系统代理 · 出口检测</p>
    </header>

    <section class="card">
      <h2>连接配置</h2>
      <label class="field">
        <span>Profile YAML</span>
        <textarea id="profile" rows="12" spellcheck="false" placeholder="粘贴含内联代理的 Mihomo YAML"></textarea>
      </label>
      <div class="row">
        <label class="field grow">
          <span>选中 IPv6</span>
          <input id="selected-ip" type="text" placeholder="2001:db8::1" />
        </label>
        <label class="field">
          <span>模式</span>
          <select id="mode">
            <option value="rule">规则</option>
            <option value="global">全局</option>
            <option value="direct">直连</option>
          </select>
        </label>
      </div>
      <label class="check">
        <input id="sys-proxy" type="checkbox" />
        <span>启用系统代理（127.0.0.1:11451，仅 Windows 生效）</span>
      </label>
      <div class="actions">
        <button id="btn-project" type="button">生成运行配置</button>
        <button id="btn-start" type="button" class="primary">启动 Mihomo</button>
        <button id="btn-stop" type="button">停止</button>
        <button id="btn-proxy-apply" type="button">应用系统代理</button>
        <button id="btn-proxy-clear" type="button">清除系统代理</button>
        <button id="btn-exit-ip" type="button">检测出口 IP</button>
      </div>
      <p id="status" class="status muted">就绪</p>
      <p id="proxy-status" class="status muted"></p>
      <p id="exit-ip" class="status muted"></p>
    </section>

    <section class="card">
      <h2>运行配置预览</h2>
      <pre id="runtime-yaml" class="code"># 点击「生成运行配置」</pre>
    </section>
  </main>
`;

const profileEl = document.querySelector<HTMLTextAreaElement>("#profile")!;
const selectedIpEl = document.querySelector<HTMLInputElement>("#selected-ip")!;
const modeEl = document.querySelector<HTMLSelectElement>("#mode")!;
const sysProxyEl = document.querySelector<HTMLInputElement>("#sys-proxy")!;
const runtimeEl = document.querySelector<HTMLPreElement>("#runtime-yaml")!;
const statusEl = document.querySelector<HTMLParagraphElement>("#status")!;
const proxyStatusEl = document.querySelector<HTMLParagraphElement>("#proxy-status")!;
const exitIpEl = document.querySelector<HTMLParagraphElement>("#exit-ip")!;

function setStatus(text: string, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

async function refreshCoreStatus() {
  try {
    const status = await invoke<CoreStatus>("core_status");
    if (status.running) {
      setStatus(`Mihomo 运行中${status.pid != null ? ` (pid ${status.pid})` : ""}`);
    }
  } catch {
    // ignore when not in tauri webview
  }
}

async function refreshProxyStatus() {
  try {
    const status = await invoke<SystemProxyStatus>("system_proxy_status");
    proxyStatusEl.textContent = status.message;
    sysProxyEl.checked = status.enabled && status.managedByViasix;
  } catch (error) {
    proxyStatusEl.textContent = `系统代理状态不可用：${error}`;
  }
}

document.querySelector("#btn-project")!.addEventListener("click", async () => {
  try {
    const mode = modeEl.value as RoutingMode;
    const yaml = await invoke<string>("project_runtime_config", {
      profileYaml: profileEl.value,
      selectedAddress: mode === "direct" ? null : selectedIpEl.value || null,
      routingMode: mode,
    });
    runtimeEl.textContent = yaml;
    setStatus("投影成功");
  } catch (error) {
    runtimeEl.textContent = String(error);
    setStatus(`投影失败：${error}`, true);
  }
});

document.querySelector("#btn-start")!.addEventListener("click", async () => {
  try {
    const mode = modeEl.value as RoutingMode;
    const status = await invoke<CoreStatus>("start_core", {
      profileYaml: profileEl.value,
      selectedAddress: mode === "direct" ? null : selectedIpEl.value || null,
      routingMode: mode,
      enableSystemProxy: sysProxyEl.checked,
    });
    setStatus(status.message);
    await refreshProxyStatus();
  } catch (error) {
    setStatus(`启动失败：${error}`, true);
  }
});

document.querySelector("#btn-stop")!.addEventListener("click", async () => {
  try {
    const status = await invoke<CoreStatus>("stop_core");
    setStatus(status.message);
    await refreshProxyStatus();
  } catch (error) {
    setStatus(`停止失败：${error}`, true);
  }
});

document.querySelector("#btn-proxy-apply")!.addEventListener("click", async () => {
  try {
    const status = await invoke<SystemProxyStatus>("set_system_proxy", {
      enabled: true,
      host: "127.0.0.1",
      port: 11451,
    });
    proxyStatusEl.textContent = status.message;
    sysProxyEl.checked = true;
  } catch (error) {
    proxyStatusEl.textContent = `应用系统代理失败：${error}`;
    proxyStatusEl.classList.add("error");
  }
});

document.querySelector("#btn-proxy-clear")!.addEventListener("click", async () => {
  try {
    const status = await invoke<SystemProxyStatus>("set_system_proxy", {
      enabled: false,
    });
    proxyStatusEl.textContent = status.message;
    proxyStatusEl.classList.remove("error");
    sysProxyEl.checked = false;
  } catch (error) {
    proxyStatusEl.textContent = `清除系统代理失败：${error}`;
    proxyStatusEl.classList.add("error");
  }
});

document.querySelector("#btn-exit-ip")!.addEventListener("click", async () => {
  exitIpEl.textContent = "检测中…";
  exitIpEl.classList.remove("error");
  try {
    const result = await invoke<ExitIpResult>("detect_exit_ip");
    exitIpEl.textContent = `${result.message}（来源 ${result.source}）`;
  } catch (error) {
    exitIpEl.textContent = `出口检测失败：${error}`;
    exitIpEl.classList.add("error");
  }
});

selectedIpEl.value = "2001:db8::1";
profileEl.value = `proxies:
  - name: My VLESS
    type: vless
    server: origin.example.com
    port: 443
    uuid: 11111111-1111-4111-1111-111111111111
    network: ws
    tls: true
    servername: origin.example.com
    ws-opts:
      path: /proxy
      headers:
        Host: origin.example.com
x-viasix:
  version: 1
  primary-server: selected-ip
`;

void refreshCoreStatus();
void refreshProxyStatus();
