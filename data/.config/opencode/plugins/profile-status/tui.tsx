// Plugin CLI (TUI) — indicador de perfil do opencode-pf dentro do opencode.
//
// Lê OPENCODE_PROFILE (exportado por `opencode-pf run <perfil>` antes do exec)
// e renderiza um badge no rodapé da home e acima do prompt. Sem OPENCODE_PROFILE
// (opencode puro, sem perfil) não renderiza nada.
//
// O ícone reflete o estado do sandbox via OPENCODE_PF_JAIL (exportado pelo
// script): "🔐 <perfil>" com ai-jail ativo; "🤞 <perfil>" rodando com
// --no-jail (binário direto, sem sandbox). Ausente/indefinido → 🔐 (conservador).
//
// Descoberta automática: <config-dir>/plugins/profile-status/tui.tsx — o
// config-dir do perfil é ~/.config/opencode-multi/profiles/<perfil>, então o
// plugin só aparece quando o perfil está ativo. Nada é tocado no cli.json
// (sensível/local), o symlink do diretório vem de data/.config/opencode/plugins.
import { Plugin } from "@opencode/plugin/tui"

export default Plugin.define({
  id: "opencode-pf.profile-status",
  setup(context) {
    const profile = process.env.OPENCODE_PROFILE
    if (!profile) return

    const jail = process.env.OPENCODE_PF_JAIL !== "0"
    const badge = () => (
      <text fg={context.theme.text.base}>{jail ? "🔐" : "🤞"} {profile}</text>
    )

    const unregisterHome = context.ui.slot({
      append: "home.footer.status",
      render: badge,
    })
    const unregisterPrompt = context.ui.slot({
      append: "prompt.footer.status",
      render: badge,
    })

    return () => {
      unregisterHome()
      unregisterPrompt()
    }
  },
})