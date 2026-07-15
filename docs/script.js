document.documentElement.classList.add("js");

(() => {
    "use strict";

    const translations = {
        "zh-CN": {
            "meta.title": "cdp — 别再找路，直接开工",
            "meta.description": "cdp 是面向 Vibe Coding 工作流的终端项目工作台：模糊切换项目、检查多仓库 Git 状态，并一键启动 AI CLI 或编辑器。",
            "a11y.skip": "跳到主要内容",
            "a11y.nav": "主导航",
            "a11y.home": "cdp 首页",
            "a11y.language": "语言",
            "a11y.heroFacts": "核心特性",
            "a11y.heroDemo": "cdp 路由示例",
            "a11y.oldRoute": "传统路径切换",
            "a11y.commandTabs": "cdp 命令",
            "a11y.installTabs": "安装平台",
            "a11y.platformDiagram": "平台路线汇合图",
            "nav.menu": "打开菜单",
            "nav.close": "关闭菜单",
            "nav.why": "为什么需要",
            "nav.commands": "真实命令",
            "nav.demo": "演示",
            "nav.install": "安装",
            "hero.kicker": "终端项目工作台 · Windows / macOS / Linux",
            "hero.line1": "别再找路。",
            "hero.line2": "直接开工。",
            "hero.lede": "找到正确项目、看清所有仓库状态，再把 Codex、Claude Code 或编辑器直接启动在正确上下文里。",
            "hero.install": "安装 cdp",
            "hero.github": "查看 GitHub",
            "hero.fact1": "模糊搜索，直接到项目根目录",
            "hero.fact2": "一屏看清所有仓库 Git 状态",
            "hero.fact3": "一步启动 AI CLI 或编辑器",
            "hero.routeReady": "ROUTE READY",
            "hero.destination": "目的地",
            "hero.branch": "分支",
            "hero.state": "状态",
            "hero.launch": "启动",
            "pain.signal": "真正拖慢你的，不是键盘。",
            "pain.title": "是每次开工前，重新寻找上下文。",
            "pain.lede": "你记住路径、逐个检查仓库、再重启工具。cdp 把这些零碎动作压成一条可重复的路线。",
            "pain.pathTitle": "长路径不是知识，是负担。",
            "pain.pathBody": "不用记盘符、父目录和项目全名。输入几个字母，唯一匹配时直接到达。",
            "pain.stateTitle": "五十个仓库，不该查五十次。",
            "pain.stateBody": "dirty、untracked、ahead、behind 和最近提交时间，一条命令全部展开。",
            "pain.startTitle": "工具启动了，上下文却错了。",
            "pain.startBody": "先进入项目，再启动 Codex、Claude、Gemini、VS Code 或 Cursor。",
            "commands.signal": "不是功能清单，是可执行路线。",
            "commands.title": "一个入口，接管项目上下文。",
            "commands.switch": "模糊选择并进入项目",
            "commands.status": "检查全部仓库状态",
            "commands.open": "进入项目并启动 AI CLI",
            "commands.workspace": "打开多项目工作区",
            "commands.doctor": "检查并修复配置",
            "commands.terminal": "LIVE ROUTE",
            "commands.arrival": "ARRIVAL",
            "scenario.switch.intent": "从任意目录锁定目的地。",
            "scenario.switch.result": "当前 shell 已进入项目根目录",
            "scenario.status.intent": "一次扫描所有仓库，只留下需要关注的项目。",
            "scenario.status.result": "dirty、untracked 与未推送提交已汇总",
            "scenario.open.intent": "让 AI CLI 从正确项目根目录启动。",
            "scenario.open.result": "Codex 已在 my-api 上下文中启动",
            "scenario.workspace.intent": "把一组相关项目作为一个工作区打开。",
            "scenario.workspace.result": "前端、API 与文档项目已同时就位",
            "scenario.doctor.intent": "在问题影响工作前检查依赖和配置。",
            "scenario.doctor.result": "fzf、配置和项目路径全部健康",
            "proof.signal": "不相信宣传？看真实终端。",
            "proof.title": "从仓库全景，到 AI CLI 启动。",
            "proof.lede": "v2.0 演示展示 status 仪表盘、智能跳转、workspace、onEnter、Tab 补全和全平台支持。",
            "proof.openVideo": "单独打开演示视频 ↗",
            "proof.duration": "真实产品录屏",
            "proof.videoFallback": "你的浏览器无法播放视频。",
            "proof.downloadVideo": "下载 MP4",
            "platform.signal": "不同 shell，同一份项目地图。",
            "platform.title": "四条路线，汇入同一个工作台。",
            "platform.lede": "PowerShell 与 bash / zsh 共享同类配置。Windows 路径进入 WSL 时自动转换，不需要维护两套项目清单。",
            "platform.destination": "SHARED DESTINATION",
            "install.signal": "选择你的入口。",
            "install.title": "下一条命令，直接到 cdp。",
            "install.lede": "无需构建工具。选择平台、复制命令，然后运行 `cdp doctor` 验证环境。",
            "install.powershell": "通过 PowerShell Gallery 安装模块，再安装 fzf。",
            "install.linux": "一条脚本安装 cdp、fzf 和 jq，然后重新载入 shell。",
            "install.macos": "先用 Homebrew 安装依赖，再运行跨平台安装脚本。",
            "install.copy": "复制命令",
            "install.copied": "已复制",
            "install.copySuccess": "命令已复制到剪贴板。",
            "install.copyManual": "命令已选中，请按 Ctrl+C 或 ⌘C 复制。",
            "install.copyError": "无法自动复制，请手动选择命令。",
            "install.gallery": "PowerShell Gallery ↗",
            "install.docs": "完整安装文档 ↗",
            "footer.tagline": "终端里的项目跃迁车道。",
            "footer.docs": "中文文档",
            "footer.note": "为多仓库与 AI CLI 工作流而生。"
        },
        en: {
            "meta.title": "cdp — Stop navigating. Start shipping.",
            "meta.description": "cdp is the terminal project workbench for Vibe Coding: fuzzy-switch projects, inspect every repository, and launch your AI CLI in the right context.",
            "a11y.skip": "Skip to main content",
            "a11y.nav": "Primary navigation",
            "a11y.home": "cdp home",
            "a11y.language": "Language",
            "a11y.heroFacts": "Core capabilities",
            "a11y.heroDemo": "cdp routing example",
            "a11y.oldRoute": "Traditional directory switching",
            "a11y.commandTabs": "cdp commands",
            "a11y.installTabs": "Installation platforms",
            "a11y.platformDiagram": "Platform routes merging into one destination",
            "nav.menu": "Open menu",
            "nav.close": "Close menu",
            "nav.why": "Why cdp",
            "nav.commands": "Real commands",
            "nav.demo": "Demo",
            "nav.install": "Install",
            "hero.kicker": "TERMINAL PROJECT WORKBENCH · WINDOWS / MACOS / LINUX",
            "hero.line1": "Stop navigating.",
            "hero.line2": "Start shipping.",
            "hero.lede": "Find the right project, see every repository state, then launch Codex, Claude Code, or your editor inside the correct context.",
            "hero.install": "Install cdp",
            "hero.github": "View on GitHub",
            "hero.fact1": "Fuzzy-search straight to the project root",
            "hero.fact2": "See every repository state in one view",
            "hero.fact3": "Launch an AI CLI or editor in one step",
            "hero.routeReady": "ROUTE READY",
            "hero.destination": "Destination",
            "hero.branch": "Branch",
            "hero.state": "State",
            "hero.launch": "Launch",
            "pain.signal": "Your keyboard is not the bottleneck.",
            "pain.title": "Rebuilding context before every session is.",
            "pain.lede": "You remember paths, inspect repositories one by one, and restart tools. cdp compresses those fragments into one repeatable route.",
            "pain.pathTitle": "Long paths are baggage, not knowledge.",
            "pain.pathBody": "Forget drive letters, parent folders, and exact names. Type a few letters and jump directly when there is one match.",
            "pain.stateTitle": "Fifty repositories should not mean fifty checks.",
            "pain.stateBody": "Dirty, untracked, ahead, behind, and last commit time arrive in one command.",
            "pain.startTitle": "The tool launched. The context did not.",
            "pain.startBody": "Enter the project first, then launch Codex, Claude, Gemini, VS Code, or Cursor.",
            "commands.signal": "Not a feature list. Executable routes.",
            "commands.title": "One entry point for project context.",
            "commands.switch": "Fuzzy-select and enter a project",
            "commands.status": "Inspect every repository",
            "commands.open": "Enter a project and launch an AI CLI",
            "commands.workspace": "Open a multi-project workspace",
            "commands.doctor": "Check and repair configuration",
            "commands.terminal": "LIVE ROUTE",
            "commands.arrival": "ARRIVAL",
            "scenario.switch.intent": "Lock onto a destination from anywhere.",
            "scenario.switch.result": "The current shell is now at the project root",
            "scenario.status.intent": "Scan every repository and keep only what needs attention.",
            "scenario.status.result": "Dirty work, untracked files, and unpushed commits are summarized",
            "scenario.open.intent": "Launch your AI CLI from the correct project root.",
            "scenario.open.result": "Codex launched inside the my-api context",
            "scenario.workspace.intent": "Open a related set of projects as one workspace.",
            "scenario.workspace.result": "Frontend, API, and documentation projects are ready together",
            "scenario.doctor.intent": "Check dependencies and configuration before they interrupt work.",
            "scenario.doctor.result": "fzf, configuration, and project paths are healthy",
            "proof.signal": "Skip the claims. Watch the terminal.",
            "proof.title": "From repository overview to AI CLI launch.",
            "proof.lede": "The v2.0 demo covers the status dashboard, direct jumps, workspaces, onEnter, Tab completion, and cross-platform support.",
            "proof.openVideo": "Open the demo video ↗",
            "proof.duration": "REAL PRODUCT CAPTURE",
            "proof.videoFallback": "Your browser cannot play this video.",
            "proof.downloadVideo": "Download MP4",
            "platform.signal": "Different shells. One project map.",
            "platform.title": "Four routes merge into one workbench.",
            "platform.lede": "PowerShell and bash / zsh share the same configuration shape. Windows paths convert automatically when entering WSL, so there is no second project list to maintain.",
            "platform.destination": "SHARED DESTINATION",
            "install.signal": "Choose your entry point.",
            "install.title": "Your next command goes straight to cdp.",
            "install.lede": "No build tools required. Pick a platform, copy the command, then run `cdp doctor` to verify the environment.",
            "install.powershell": "Install the module from PowerShell Gallery, then install fzf.",
            "install.linux": "One script installs cdp, fzf, and jq, then reloads your shell.",
            "install.macos": "Install dependencies with Homebrew, then run the cross-platform installer.",
            "install.copy": "Copy command",
            "install.copied": "Copied",
            "install.copySuccess": "Command copied to the clipboard.",
            "install.copyManual": "Command selected. Press Ctrl+C or ⌘C to copy.",
            "install.copyError": "Automatic copy failed. Select the command manually.",
            "install.gallery": "PowerShell Gallery ↗",
            "install.docs": "Full installation guide ↗",
            "footer.tagline": "The warp lane for terminal projects.",
            "footer.docs": "English docs",
            "footer.note": "Built for multi-repository and AI CLI workflows."
        }
    };

    const commandScenarios = {
        switch: {
            intentKey: "scenario.switch.intent",
            resultKey: "scenario.switch.result",
            lines: [
                ["PS C:\\> cdp", ""],
                ["56 projects · type to filter · enter to warp", "output-muted"],
                ["> my-api    C:\\Work\\my-api", "output-highlight"],
                ["✓ destination locked · C:\\Work\\my-api", "output-success"]
            ]
        },
        status: {
            intentKey: "scenario.status.intent",
            resultKey: "scenario.status.result",
            lines: [
                ["PS C:\\> cdp status --dirty", ""],
                ["PROJECT       BRANCH   STATE       SYNC", "output-muted"],
                ["my-api        main     × 3 dirty   ↑1", "output-warning"],
                ["admin-panel   dev      ! 2 new     —", "output-warning"],
                ["3 repos need attention", "output-highlight"]
            ]
        },
        open: {
            intentKey: "scenario.open.intent",
            resultKey: "scenario.open.result",
            lines: [
                ["PS C:\\> cdp api -Open codex", ""],
                ["query        api", "output-muted"],
                ["destination  C:\\Work\\my-api", "output-highlight"],
                ["state        clean", "output-success"],
                ["launching    codex →", "output-success"]
            ]
        },
        workspace: {
            intentKey: "scenario.workspace.intent",
            resultKey: "scenario.workspace.result",
            lines: [
                ["$ cdp workspace product", ""],
                ["workspace    product", "output-muted"],
                ["+ web-app    ~/Work/web-app", "output-success"],
                ["+ my-api     ~/Work/my-api", "output-success"],
                ["+ docs       ~/Work/docs", "output-success"]
            ]
        },
        doctor: {
            intentKey: "scenario.doctor.intent",
            resultKey: "scenario.doctor.result",
            lines: [
                ["PS C:\\> cdp doctor", ""],
                ["✓ fzf              available", "output-success"],
                ["✓ project config   valid JSON", "output-success"],
                ["✓ duplicate names  none", "output-success"],
                ["✓ project paths    all healthy", "output-success"]
            ]
        }
    };

    const installOptions = {
        powershell: {
            descriptionKey: "install.powershell",
            command: "Install-Module -Name cdp -Scope CurrentUser\nwinget install fzf\nImport-Module cdp\ncdp doctor"
        },
        linux: {
            descriptionKey: "install.linux",
            command: "bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto\nsource ~/.bashrc\ncdp doctor"
        },
        macos: {
            descriptionKey: "install.macos",
            command: "brew install fzf jq\nbash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto\nsource ~/.zshrc\ncdp doctor"
        }
    };

    const state = {
        language: getPreferredLanguage(),
        command: "switch",
        platform: "powershell",
        navOpen: false,
        copyTimer: null
    };

    function getPreferredLanguage() {
        try {
            const saved = localStorage.getItem("cdp-language");
            if (saved && translations[saved]) return saved;
        } catch {}
        return "en";
    }

    function text(key) {
        return translations[state.language][key] || translations["zh-CN"][key] || key;
    }

    function applyTranslations() {
        document.documentElement.lang = state.language;
        document.title = text("meta.title");
        updateMeta("meta[name='description']", text("meta.description"));
        updateMeta("meta[property='og:title']", text("meta.title"));
        updateMeta("meta[property='og:description']", text("meta.description"));
        document.querySelectorAll("[data-i18n]").forEach((element) => {
            element.textContent = text(element.dataset.i18n);
        });
        document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
            element.setAttribute("aria-label", text(element.dataset.i18nAriaLabel));
        });
        updateLanguageLinks();
    }

    function updateMeta(selector, content) {
        const element = document.querySelector(selector);
        if (element) element.setAttribute("content", content);
    }

    function updateLanguageLinks() {
        const english = state.language === "en";
        const docsHash = english ? "README.md#quick-start" : "README_ZH.md#快速开始";
        const docsFile = english ? "README.md" : "README_ZH.md";
        const base = "https://github.com/GoldenZqqq/cdp/blob/main/";
        const installLink = document.querySelector("[data-docs-link]");
        const footerLink = document.querySelector("[data-footer-docs]");
        if (installLink) installLink.href = `${base}${docsHash}`;
        if (footerLink) footerLink.href = `${base}${docsFile}`;
    }

    function setLanguage(language) {
        if (!translations[language]) return;
        state.language = language;
        try {
            localStorage.setItem("cdp-language", language);
        } catch {}
        document.querySelectorAll("[data-language]").forEach((button) => {
            button.setAttribute("aria-pressed", String(button.dataset.language === language));
        });
        applyTranslations();
        setCommand(state.command);
        setPlatform(state.platform);
        updateNav();
    }

    function renderTerminal(lines) {
        const output = document.querySelector("[data-command-output]");
        if (!output) return;
        output.replaceChildren(...lines.map(([content, tone]) => {
            const line = document.createElement("p");
            line.textContent = content;
            if (tone) line.className = tone;
            return line;
        }));
    }

    function setCommand(commandName, focusPanel = false) {
        const scenario = commandScenarios[commandName];
        const panel = document.querySelector("#command-panel");
        if (!scenario || !panel) return;
        state.command = commandName;
        document.querySelectorAll("[data-command]").forEach((button) => {
            const selected = button.dataset.command === commandName;
            button.setAttribute("aria-selected", String(selected));
            button.tabIndex = selected ? 0 : -1;
            if (selected) panel.setAttribute("aria-labelledby", button.id);
        });
        document.querySelector("[data-command-intent]").textContent = text(scenario.intentKey);
        document.querySelector("[data-command-result]").textContent = text(scenario.resultKey);
        renderTerminal(scenario.lines);
        if (focusPanel) panel.focus();
    }

    function setPlatform(platformName) {
        const option = installOptions[platformName];
        const panel = document.querySelector("#install-panel");
        if (!option || !panel) return;
        state.platform = platformName;
        document.querySelectorAll("[data-platform]").forEach((button) => {
            const selected = button.dataset.platform === platformName;
            button.setAttribute("aria-selected", String(selected));
            button.tabIndex = selected ? 0 : -1;
            if (selected) panel.setAttribute("aria-labelledby", button.id);
        });
        document.querySelector("[data-install-description]").textContent = text(option.descriptionKey);
        document.querySelector("[data-install-command]").textContent = option.command;
        document.querySelector("[data-copy-status]").textContent = "";
    }

    function bindTabList(container, itemSelector, onSelect) {
        if (!container) return;
        const items = () => [...container.querySelectorAll(itemSelector)];
        container.addEventListener("click", (event) => {
            const item = event.target.closest(itemSelector);
            if (item) onSelect(item);
        });
        container.addEventListener("keydown", (event) => {
            const options = items();
            const currentIndex = options.indexOf(event.target.closest(itemSelector));
            const nextIndex = getNextTabIndex(event.key, currentIndex, options.length);
            if (nextIndex === null) return;
            event.preventDefault();
            options[nextIndex].focus();
            onSelect(options[nextIndex]);
        });
    }

    function getNextTabIndex(key, currentIndex, length) {
        if (currentIndex < 0) return null;
        if (["ArrowRight", "ArrowDown"].includes(key)) return (currentIndex + 1) % length;
        if (["ArrowLeft", "ArrowUp"].includes(key)) return (currentIndex - 1 + length) % length;
        if (key === "Home") return 0;
        if (key === "End") return length - 1;
        return null;
    }

    function updateNav() {
        const panel = document.querySelector("[data-nav-panel]");
        const toggle = document.querySelector("[data-nav-toggle]");
        if (!panel || !toggle) return;
        panel.classList.toggle("is-open", state.navOpen);
        toggle.setAttribute("aria-expanded", String(state.navOpen));
        const label = toggle.querySelector(".sr-only");
        if (label) label.textContent = text(state.navOpen ? "nav.close" : "nav.menu");
    }

    function selectText(element) {
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(element);
        selection.removeAllRanges();
        selection.addRange(range);
    }

    async function copyCommand(button) {
        const target = document.getElementById(button.dataset.copyTarget);
        const status = document.querySelector("[data-copy-status]");
        if (!target || !status) return;
        clearTimeout(state.copyTimer);
        try {
            if (!navigator.clipboard || !window.isSecureContext) {
                selectText(target);
                status.textContent = text("install.copyManual");
                return;
            }
            await navigator.clipboard.writeText(target.textContent);
            status.textContent = text("install.copySuccess");
            button.querySelector("[data-copy-label]").textContent = text("install.copied");
            state.copyTimer = setTimeout(() => {
                button.querySelector("[data-copy-label]").textContent = text("install.copy");
            }, 1600);
        } catch {
            selectText(target);
            status.textContent = text("install.copyError");
        }
    }

    function bindInteractions() {
        document.querySelectorAll("[data-language]").forEach((button) => {
            button.addEventListener("click", () => setLanguage(button.dataset.language));
        });
        bindTabList(document.querySelector("[data-command-tabs]"), "[data-command]", (button) => setCommand(button.dataset.command));
        bindTabList(document.querySelector("[data-install-tabs]"), "[data-platform]", (button) => setPlatform(button.dataset.platform));
        document.querySelector("[data-copy-target]")?.addEventListener("click", (event) => copyCommand(event.currentTarget));
        document.querySelector("[data-nav-toggle]")?.addEventListener("click", () => {
            state.navOpen = !state.navOpen;
            updateNav();
        });
        document.querySelectorAll("[data-nav-panel] a").forEach((link) => {
            link.addEventListener("click", () => {
                state.navOpen = false;
                updateNav();
            });
        });
        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape" && state.navOpen) {
                state.navOpen = false;
                updateNav();
                document.querySelector("[data-nav-toggle]")?.focus();
            }
        });
    }

    function bindHeader() {
        const header = document.querySelector("[data-site-header]");
        if (!header) return;
        const update = () => header.classList.toggle("is-scrolled", window.scrollY > 24);
        update();
        window.addEventListener("scroll", update, { passive: true });
    }

    applyTranslations();
    setLanguage(state.language);
    bindInteractions();
    bindHeader();
})();
