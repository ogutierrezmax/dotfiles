// Plugin CLI (TUI) — indicador de estado do sandbox ai-jail.
//
// O que faz:
//   - Deriva o modo de execução de DOIS sinais independentes:
//       - hostname (fato do kernel: o UTS namespace só se chama 'ai-sandbox'
//         depois que o bwrap aplicou --unshare-uts --hostname)
//       - AI_EXECUTION_MODE (INTENÇÃO declarada pelo launcher)
//   - Pinta um círculo no rodapé (home.footer.status + prompt.footer.status):
//       🟢 jail  — dentro do jail, variável concorda
//       ⚪ host  — fora do jail, variável concorda
//       🔴 jail/host — DIVERGÊNCIA (os dois sinais discordam)
//     A palavra é sempre o FATO (o que o kernel diz); a cor é o ACORDO entre
//     os dois sinais. Assim o 🔴 ainda mostra onde você está de verdade.
//   - Clique no círculo, ou o comando /jail na paleta, abre um dialog com o
//     diagnóstico completo: regra do AGENTS.md aplicada, hostname, variável,
//     se o $HOME é tmpfs (confirmação independente do jail), config-dir,
//     socket do docker e PID.
//
// Por que dois sinais: uma variável de ambiente registra a INTENÇÃO de quem
// lançou, não o fato. `scripts/opencode-pf.sh:309` exporta AI_EXECUTION_MODE=jail
// ANTES de o jail existir, e o wrapper `data/.local/bin/opencode` usava essa
// variável para decidir se pulava o ai-jail — então ela dizia "jail" numa sessão
// que rodava no host. O hostname não pode mentir: nenhum `export` cria um
// namespace. As regras de combinação são as do data/.config/opencode/AGENTS.md:
//   - hostname == ai-sandbox                  → JAIL, qualquer que seja a variável
//   - hostname != ai-sandbox e variável host  → HOST
//   - hostname != ai-sandbox e variável jail  → HOST COM ALERTA (divergência:
//     a variável diz que está preso, mas não está — a direção perigosa)
//
// Sem reatividade: o estado não muda em runtime (não dá pra entrar ou sair da
// jail sem reiniciar o opencode), então o badge lê os sinais a cada render em
// vez de observar nada. Isso mantém badge e dialog impossíveis de divergir.
//
// Descoberta automática: <config-dir>/plugins/jail-status/tui.tsx. Sem perfil
// (opencode puro) e sem jail (--no-jail) o plugin SEMPRE renderiza — o ⚪ é
// informação, não ruído. Espelhado por perfil via config/opencode-profiles.list
// e linkado no config padrão via config/dotfile-names.list; na jail ele entra
// sozinho, porque data/.local/bin/ai-jail:205 symlinka o dir 'plugins' inteiro.
import { Plugin } from "@opencode/plugin/tui"
import * as fs from "node:fs"
import * as os from "node:os"

type Declared = "jail" | "host" | "unset"
type Verdict = {
  /** Fato do kernel: estamos fisicamente dentro do sandbox? */
  jailed: boolean
  hostname: string
  /** Intenção declarada pelo launcher. */
  declared: Declared
  /** Os dois sinais discordam. */
  divergent: boolean
  /** A divergência diz "solto fingindo estar preso" (perigoso) ou o oposto? */
  unsafe: boolean
}

const read = (): Verdict => {
  const hostname = os.hostname()
  const jailed = hostname === "ai-sandbox"
  const raw = process.env.AI_EXECUTION_MODE
  const declared: Declared = raw === "jail" ? "jail" : raw === "host" ? "host" : "unset"
  // "unset" é ausência de claim, não contradição: quem não falou não pode
  // discordar. Fora do jail ela é o estado NORMAL (o `opencode` puro não
  // exporta nada; o wrapper só exporta no caminho --no-jail), então ali
  // ausente concorda com "host". Dentro do jail ela é praticamente impossível
  // (ai-jail:310 sempre faz --setenv) e, se ainda assim acontecer, o AGENTS.md
  // manda considerar JAIL com qualquer valor de variável — logo 🟢.
  const claimed = declared === "unset" ? (jailed ? "jail" : "host") : declared
  const divergent = (claimed === "jail") !== jailed
  return { jailed, hostname, declared, divergent, unsafe: !jailed && declared === "jail" }
}

const DECLARED_TEXT: Record<Declared, string> = {
  jail: "jail",
  host: "host",
  unset: "(ausente)",
}

const rule = (v: Verdict): string => {
  if (v.jailed) return "hostname == ai-sandbox → JAIL (o kernel não mente)"
  if (v.declared === "jail") return "hostname != ai-sandbox e variável == jail → HOST com alerta"
  return "hostname != ai-sandbox e variável " + (v.declared === "host" ? "== host" : "ausente") + " → HOST"
}

// Confirmação independente do jail: ai-jail:295 monta o $HOME como
// "--tmpfs $HOME:size=512M". Se o nosso $HOME é tmpfs, o bwrap rodou — e isso
// não depende nem do hostname nem da variável.
const homeIsTmpfs = (): boolean | null => {
  try {
    const home = os.homedir()
    for (const line of fs.readFileSync("/proc/self/mountinfo", "utf8").split("\n")) {
      const parts = line.split(" ")
      if (parts[4] !== home) continue
      const sep = parts.indexOf("-")
      return sep !== -1 && parts[sep + 1] === "tmpfs"
    }
    return null
  } catch {
    return null
  }
}

const socketExists = (path: string): boolean | null => {
  try {
    return fs.existsSync(path)
  } catch {
    return null
  }
}

const tri = (value: boolean | null, yes: string, no: string): string => (value === null ? "?" : value ? yes : no)

export default Plugin.define({
  id: "opencode.jail-status",
  setup(context) {
    const openDetail = () => {
      context.ui.dialog.show(
        () => {
          const v = read()
          const color = v.divergent
            ? context.theme.text.feedback.error.base
            : v.jailed
              ? context.theme.text.feedback.success.base
              : context.theme.text.muted
          const dot = v.divergent ? "🔴" : v.jailed ? "🟢" : "⚪"
          const label = v.divergent ? (v.jailed ? "JAIL — DIVERGENTE" : "HOST — DIVERGENTE") : v.jailed ? "JAIL ATIVO" : "HOST"
          const profile = process.env.OPENCODE_PROFILE
          return (
            <box padding={1} flexDirection="column">
              {/* Título no topo — padrão do DialogConfirm nativo (bold + "esc"). */}
              <box flexDirection="row" justifyContent="space-between">
                <text bold>jail</text>
                <text dim>esc</text>
              </box>
              <text fg={color}>
                {dot} {label}
              </text>
              {v.divergent && (
                <text fg={context.theme.text.feedback.warning.base}>
                  {v.unsafe
                    ? "⚠ solto com a variável dizendo jail — trate como HOST"
                    : "preso com a variável dizendo host — falha para o lado seguro"}
                </text>
              )}
              <text dim>  regra: {rule(v)}</text>
              <text>  hostname:      {v.hostname}</text>
              <text>  variável:      {DECLARED_TEXT[v.declared]}</text>
              <text>  $HOME tmpfs:   {tri(homeIsTmpfs(), "sim", "não")}</text>
              <text>  config-dir:    {process.env.OPENCODE_CONFIG_DIR ?? "(padrão do host)"}</text>
              {profile && <text>  perfil:       {profile}</text>}
              <text>  docker socket: {tri(socketExists("/var/run/docker.sock"), "acessível", "ausente")}</text>
              <text>  pid:           {process.pid}</text>
              <text dim>  clique fora ou esc fecha</text>
            </box>
          )
        },
        () => {},
      )
      // O show() do plugin chama replace(), que RESETA centered=false sem
      // exceção — então o set é reaplicado DEPOIS do flush do replace, senão o
      // modal abre deslocado. Mesmo padrão do token-daily e do viewer nativo.
      setTimeout(() => context.ui.dialog.set({ size: "medium", centered: true }), 0)
    }

    // Layers do keymap — registradas por COMPONENTE, não no setup(). O setup()
    // do plugin roda fora do Keymap.Provider do host, então context.keymap.layer()
    // lá lança "Keymap.Provider is missing" (erro que um try/catch silencioso
    // engolia, deixando a paleta e o slash mortos). Montado via slot, este
    // componente executa sob o provider e o Solid desregistra a layer sozinho
    // ao desmontar (ownership), sem cleanup manual.
    const KeymapLayers = () => {
      context.keymap.layer(() => ({
        mode: "global",
        priority: 10,
        commands: [
          {
            id: "opencode.jail-status.detail",
            title: "jail: estado do sandbox",
            group: "jail-status",
            palette: true,
            slash: { name: "jail" },
            run: openDetail,
          },
        ],
      }))
      return null
    }

    const badge = () => {
      const v = read()
      const color = v.divergent
        ? context.theme.text.feedback.error.base
        : v.jailed
          ? context.theme.text.feedback.success.base
          : context.theme.text.muted
      const dot = v.divergent ? "🔴" : v.jailed ? "🟢" : "⚪"
      return (
        <text
          fg={color}
          selectable={false}
          onMouseUp={(event: any) => {
            event?.preventDefault?.()
            // Abre no próximo tick: se abrisse no onMouseUp em curso, o overlay
            // recém-montado receberia o resto do evento e o Dialog (que fecha no
            // mouseup fora dele) fecharia na hora.
            setTimeout(openDetail, 0)
          }}
        >
          <u>
            {dot} {v.jailed ? "jail" : "host"}
          </u>
        </text>
      )
    }

    const unregisterHome = context.ui.slot({ append: "home.footer.status", render: badge })
    // As layers do keymap vivem no slot do PROMPT (presente na home e em
    // sessões): é aqui que KeymapLayers monta uma única vez, sob o provider do
    // host. O badge do prompt renderiza junto.
    const promptSlot = () => (
      <>
        <KeymapLayers />
        {badge()}
      </>
    )
    const unregisterPrompt = context.ui.slot({ append: "prompt.footer.status", render: promptSlot })

    return () => {
      unregisterHome()
      unregisterPrompt()
    }
  },
})
