// Plugin CLI (TUI) — contador diário de tokens (input/output) do opencode.
//
// O que faz:
//   - Escuta eventos message.updated e, como rede de segurança, re-computa os
//     totais de todas as sessões a cada 30s.
//   - Acumula APENAS o delta novo por sessão (baseline persistido em
//     "token-daily-seen") — não conta duas vezes a mesma mensagem após restart
//     (recomputar o total da sessão e subtrair o baseline já gravado).
//   - Guarda totais por dia ("YYYY-MM-DD") em storage durável ("token-daily").
//   - Renderiza no rodapé (home.footer.status + prompt.footer.status):
//        ↑5k ↓2k sublinhado — valores arredondados (sem ponto); clique (ou
//        /token-daily na paleta) abre um dialog centralizado com "token-daily"
//        no topo (linha de título bold + "esc", padrão do DialogConfirm nativo)
//        e a data do dia centralizada logo abaixo (◀ Ter 22 Set ▶ — ◀/▶ indicam
//        navegação), com o breakdown (input/output/reasoning/cache read/write,
//        com casa decimal), que fica aberto até clicar fora (ou esc). Dentro do
//        dialog, ←/→ navegam entre os dias com uso registrado (mode:"modal" +
//        enabled, sem roubar left/right do cursor no prompt).
//
// Requisito do host v2.0.12: as layers do keymap são registradas por um
// COMPONENTE montado via slot (KeymapLayers), nunca no setup(). O setup() do
// plugin roda fora do Keymap.Provider do host, então context.keymap.layer() lá
// lança "Keymap.Provider is missing" — erro que um try/catch silencioso
// engolia, deixando a paleta (No matching commands) e as setas (no-op) mortas.
// Registrado por componente (mesmo padrão do DialogConfirm nativo, que chama
// createLayer no corpo do componente), o Solid desregistra as layers sozinho
// ao desmontar o componente — sem cleanup manual.
//
// Limitações conhecidas (v1):
//   - Atribui o delta ao dia em que ele foi observado (não ao timestamp exato
//     da mensagem); sessões removidas do histórico perdem o que aconteceu com
//     o TUI fechado. Sessões ainda listadas são "pegas" pelo timer de 30s.
//   - Múltiplos TUI simultâneos no mesmo servidor podem contar a mesma
//     mensagem duas vezes (baseline compartilhado sem lock com exclusão mútua).
//   - O clique depende do terminal reportar mouse (a maioria moderna suporta);
//     o comando /token-daily funciona em qualquer terminal.
//
// Descoberta automática: <config-dir>/plugins/token-daily/tui.tsx — espelhado
// por perfil via config/opencode-profiles.list e linkado no config padrão via
// config/dotfile-names.list.
import { Plugin } from "@opencode/plugin/tui"
import { createSignal } from "solid-js"

type Counter = {
  input: number
  output: number
  reasoning: number
  cacheRead: number
  cacheWrite: number
}

const EMPTY: Counter = { input: 0, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0 }

const todayKey = (): string => {
  const d = new Date()
  const mm = String(d.getMonth() + 1).padStart(2, "0")
  const dd = String(d.getDate()).padStart(2, "0")
  return `${d.getFullYear()}-${mm}-${dd}`
}

const fmt = (n: number): string => {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`
  return String(n)
}

// Versão arredondada (sem ponto decimal) para o rodapé — ex.: 4900 → "5k".
// (o dialog usa `fmt`, com uma casa decimal)
const fmtRound = (n: number): string => {
  if (n >= 1_000_000) return `${Math.round(n / 1_000_000)}M`
  if (n >= 1_000) {
    const k = Math.round(n / 1_000)
    if (k >= 1_000) return `${Math.round(k / 1_000)}M`
    return `${k}k`
  }
  return String(n)
}

// Lê tokens tanto no formato plano (message.tokens) quanto aninhado
// (message.data.tokens — payload persistido no banco do opencode).
const readTokens = (message: any): Counter | null => {
  const t = message?.tokens ?? message?.data?.tokens
  if (!t || typeof t !== "object") return null
  return {
    input: t.input ?? 0,
    output: t.output ?? 0,
    reasoning: t.reasoning ?? 0,
    cacheRead: t.cache?.read ?? 0,
    cacheWrite: t.cache?.write ?? 0,
  }
}

export default Plugin.define({
  id: "opencode.token-daily",
  setup(context) {
    const [days, updateDays] = context.storage.store("token-daily", {
      initial: { days: {} as Record<string, Counter> },
    })
    const [seen, updateSeen] = context.storage.store("token-daily-seen", {
      initial: { sessions: {} as Record<string, Counter> },
    })

    // Soma os tokens de todas as mensagens assistant de uma sessão.
    const sessionTotals = async (sessionID: string): Promise<Counter | null> => {
      try {
        await context.data.session.message.sync(sessionID)
        const messages = (await context.data.session.message.list(sessionID)) ?? []
        const totals: Counter = { ...EMPTY }
        for (const m of messages) {
          const t = readTokens(m)
          if (!t) continue
          totals.input += t.input
          totals.output += t.output
          totals.reasoning += t.reasoning
          totals.cacheRead += t.cacheRead
          totals.cacheWrite += t.cacheWrite
        }
        return totals
      } catch {
        return null
      }
    }

    // Aplica a uma sessão apenas o DELTA novo (total atual − baseline gravado).
    const collect = async (sessionID: string) => {
      if (!sessionID) return
      const totals = await sessionTotals(sessionID)
      if (!totals) return
      const prev = seen.sessions[sessionID] ?? EMPTY
      const delta: Counter = {
        input: totals.input - prev.input,
        output: totals.output - prev.output,
        reasoning: totals.reasoning - prev.reasoning,
        cacheRead: totals.cacheRead - prev.cacheRead,
        cacheWrite: totals.cacheWrite - prev.cacheWrite,
      }
      const total = delta.input + delta.output + delta.reasoning + delta.cacheRead + delta.cacheWrite
      if (total <= 0) return
      const key = todayKey()
      await updateDays((draft: any) => {
        const day = (draft.days[key] ??= { ...EMPTY })
        day.input += delta.input
        day.output += delta.output
        day.reasoning += delta.reasoning
        day.cacheRead += delta.cacheRead
        day.cacheWrite += delta.cacheWrite
      })
      await updateSeen((draft: any) => {
        draft.sessions[sessionID] = totals
      })
    }

    // 1) Caminho principal: mensagens novas.
    let stopEvents = () => {}
    try {
      stopEvents = context.data.on("message.updated", (event: any) => {
        const sessionID = event?.data?.sessionID ?? event?.sessionID
        if (sessionID) void collect(sessionID)
      })
    } catch {
      // Fallback: escuta genérica de eventos do servidor, filtrando por tipo.
      stopEvents = (context.data.listen as any)((event: any) => {
        const type = event?.details?.type ?? event?.type ?? ""
        if (type.includes("message.updated")) {
          const sessionID =
            event?.details?.data?.sessionID ??
            event?.details?.sessionID ??
            event?.data?.sessionID ??
            event?.sessionID
          if (sessionID) void collect(sessionID)
        }
      })
    }

    // 2) Rede de segurança: re-computa todas as sessões a cada 30s (pega
    //    eventos perdidos e o que aconteceu com o TUI fechado).
    const timer = setInterval(() => {
      const sessions = context.data.session.list() ?? []
      for (const s of sessions) {
        const sessionID = s?.id ?? s?.sessionID
        if (sessionID) void collect(sessionID)
      }
    }, 30_000)

    // 3) Vira o dia mesmo sem atividade: garante re-render ao mudar a chave.
    const rollover = setInterval(() => {
      const key = todayKey()
      if (!days.days[key]) {
        updateDays((draft: any) => {
          draft.days[key] ??= { ...EMPTY }
        })
      }
    }, 60_000)

    // Texto exibido num signal (clone) — o badge só re-pinta quando muda.
    const [display, setDisplay] = createSignal("")
    let last = ""
    const paint = () => {
      const d = days.days[todayKey()]
      const total = d ? d.input + d.output + d.reasoning + d.cacheRead + d.cacheWrite : 0
      const text = total > 0 ? `↑${fmtRound(d.input)} ↓${fmtRound(d.output)}` : ""
      if (text !== last) {
        last = text
        setDisplay(text)
      }
    }
    paint()
    const paintTimer = setInterval(paint, 5_000)

    // Breakdown do dia (ou null se ainda não há uso registrado).
    const todayCounter = (): Counter | null => {
      const d = days.days[todayKey()]
      if (!d) return null
      const total = d.input + d.output + d.reasoning + d.cacheRead + d.cacheWrite
      return total > 0 ? d : null
    }

    // Navegação entre os dias com uso no modal (←/→).
    const [viewDay, setViewDay] = createSignal("")
    const [dialogOpen, setDialogOpen] = createSignal(false)
    const dayKeys = (): string[] =>
      Object.keys(days.days)
        .filter((key) => {
          const d = days.days[key]
          return !!d && d.input + d.output + d.reasoning + d.cacheRead + d.cacheWrite > 0
        })
        .sort()
    const navDay = (dir: -1 | 1) => {
      const keys = dayKeys()
      if (keys.length === 0) return
      const idx = keys.indexOf(viewDay())
      const next = idx === -1 ? (dir === 1 ? keys.length - 1 : 0) : idx + dir
      if (next < 0 || next >= keys.length) return
      setViewDay(keys[next])
    }
    const WEEKDAYS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    const MONTHS = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
    const fmtDay = (key: string): string => {
      const [y, m, d] = key.split("-").map(Number)
      return `${WEEKDAYS[new Date(y, m - 1, d).getDay()]} ${d} ${MONTHS[m - 1]}`
    }

    // Dialog com a data do dia + detalhe (←/→ navegam entre dias com uso).
    const openDetail = () => {
      if (!todayCounter()) {
        context.ui.toast.show({ message: "token-daily: nenhum uso registrado hoje ainda" })
        return
      }
      setViewDay(todayKey())
      setDialogOpen(true)
      context.ui.dialog.show(
        () => {
          const key = viewDay()
          const d = days.days[key] ?? EMPTY
          const keys = dayKeys()
          const pos = keys.indexOf(key) + 1
          const label = key === todayKey() ? `${fmtDay(key)} (hoje)` : fmtDay(key)
          return (
            <box padding={1} flexDirection="column">
              {/* Título no topo — padrão do DialogConfirm nativo (bold + "esc"). */}
              <box flexDirection="row" justifyContent="space-between">
                <text bold>token-daily</text>
                <text dim>esc</text>
              </box>
              {/* Data centralizada, com ◀ ▶ indicando navegação entre dias. */}
              <box width="100%" justifyContent="center">
                <text bold>◀  {label}  ▶</text>
              </box>
              <text>  ↑ input:        {fmt(d.input)}</text>
              <text>  ↓ output:       {fmt(d.output)}</text>
              <text>  🗣 reasoning:   {fmt(d.reasoning)}</text>
              <text>  ⚡ cache read:  {fmt(d.cacheRead)}</text>
              <text>  ⚡ cache write: {fmt(d.cacheWrite)}</text>
              <text dim>
                ← → navega dias ({pos}/{keys.length}) · clique fora ou esc fecha
              </text>
            </box>
          )
        },
        () => {
          setDialogOpen(false)
        },
      )
      // O show() do plugin chama replace(), que RESETA centered=false sem
      // exceção (n("centered",!1) no source do host v2.0.12) — então o set
      // abaixo é reaplicado DEPOIS do flush do replace, ou o modal abre com o
      // painel deslocado para baixo (faixa enorme de espaço vazio no topo).
      // Mesmo padrão do viewer de imagens nativo (setCentered(!0) pós-inserção).
      setTimeout(() => context.ui.dialog.set({ size: "medium", centered: true }), 0)
    }

    // Layers do keymap — registradas por COMPONENTE, não no setup().
    // No host v2.0.12 o setup() do plugin roda fora do Keymap.Provider, então
    // context.keymap.layer() lá lança "Keymap.Provider is missing" (silenciado
    // na versão antiga, deixando paleta e setas mortas). Montado via slot, este
    // componente executa sob o provider — padrão do DialogConfirm nativo, que
    // chama createLayer no corpo do componente. O Solid desregistra as layers
    // ao desmontar o componente (ownership), sem cleanup manual.
    const KeymapLayers = () => {
      // Comando de paleta/slash — fallback por teclado (não depende de mouse).
      context.keymap.layer(() => ({
        mode: "global",
        priority: 10,
        commands: [
          {
            id: "opencode.token-daily.detail",
            title: "token-daily: uso de tokens hoje",
            group: "token-daily",
            palette: true,
            slash: { name: "token-daily" },
            run: openDetail,
          },
        ],
      }))
      // Navegação por ←/→ entre os dias no modal. mode:"modal" (atalhos só
      // ativos com dialog aberto) + enabled (só quando É o nosso dialog), para
      // não roubar left/right do cursor no prompt.
      context.keymap.layer(() => ({
        mode: "modal",
        enabled: () => dialogOpen(),
        commands: [
          { bind: "left", title: "token-daily: dia anterior", group: "token-daily", run: () => navDay(-1) },
          { bind: "right", title: "token-daily: próximo dia", group: "token-daily", run: () => navDay(1) },
        ],
      }))
      return null
    }

    const badge = () => {
      const text = display()
      if (!text) return null
      return (
        <text
          fg={context.theme.text.base}
          selectable={false}
          onMouseUp={(event: any) => {
            event?.preventDefault?.()
            // Abre no próximo tick em vez de aqui: se abrisse no onMouseUp em
            // curso, o overlay recém-montado receberia o resto do evento e o
            // Dialog (que fecha no mouseup fora dele) fecharia na hora.
            setTimeout(openDetail, 0)
          }}
        >
          <u>{text}</u>
        </text>
      )
    }
    const unregisterHome = context.ui.slot({ append: "home.footer.status", render: badge })
    // As layers do keymap vivem no slot do PROMPT (presente na home e em
    // sessões): é aqui que KeymapLayers monta uma única vez, sob o
    // Keymap.Provider do host. O badge do prompt renderiza junto.
    const promptSlot = () => (
      <>
        <KeymapLayers />
        {badge()}
      </>
    )
    const unregisterPrompt = context.ui.slot({ append: "prompt.footer.status", render: promptSlot })

    return () => {
      stopEvents()
      clearInterval(timer)
      clearInterval(rollover)
      clearInterval(paintTimer)
      unregisterHome()
      unregisterPrompt()
    }
  },
})