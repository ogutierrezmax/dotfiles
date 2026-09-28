// Plugin CLI (TUI) — indicador de perfil do opencode-pf dentro do opencode.
//
// Lê OPENCODE_PROFILE (exportado por `opencode-pf run <perfil>` antes do exec)
// e renderiza um badge no rodapé da home e acima do prompt. Sem OPENCODE_PROFILE
// (opencode puro, sem perfil) não renderiza nada.
//
// O estado do sandbox NÃO é responsabilidade deste plugin: o ícone 🔐/🤞 e a
// leitura de OPENCODE_PF_JAIL saíram daqui para `plugins/jail-status`, que
// deriva o estado de hostname + AI_EXECUTION_MODE e por isso também funciona
// no opencode padrão (sem perfil). Aqui sobra só o nome do perfil, que é o que
// o opencode-pf de fato contribui — a variable jail do opencode-pf continua
// existindo para compat, mas nada mais a consome.
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

    const badge = () => <text fg={context.theme.text.base}>👤 {profile}</text>

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