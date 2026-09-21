// Ajuste do "limite de linhas" da resposta no system prompt do opencode.
// EDITE AQUI as duas constantes conforme sua vontade e reinicie o opencode.
// Texto inicial = seed byte a byte idêntico ao template default.txt v1.18.30.
//
// Migrado para o formato de plugin v2 (v2.0.12): o hook antigo
// `experimental.chat.system.transform` (v1) não existe mais — o plugin agora
// é um servidor plugin v2 registrando o hook de contexto de sessão
// `ctx.session.hook("context")`, que roda antes de cada chamada de modelo do
// agent loop e reescreve as instruções do system para forçar o limite de
// linhas. Descoberto automaticamente em <config-dir>/plugins/ (entrypoint de
// servidor index.ts), sem entrada explícita na config.
//
// NOTA: o default export é um objeto literal (id + setup) e NÃO importa
// `@opencode/plugin` — o schema do runtime v2.0.12 só exige id + setup/effect,
// e o Plugin.define() é só um helper de tipos. Evitar o import permite que o
// plugin de servidor carregue sem node_modules no config-dir do perfil
// (opencode resolve @opencode/plugin apenas para plugins CLI/TUI; o servidor
// exigiria o pacote instalado). Sem type-safety por isso — ctx/event seguem o
// contrato em https://opencode.ai/v2/docs/build/plugins.
const RESPONSE_RULE_PARAGRAPH =
  "You MUST answer concisely with fewer than 8 lines (not including tool use or code generation), unless user asks for detail."
const RESPONSE_RULE_FOOTER =
  "You MUST answer concisely with fewer than 8 lines of text (not including tool use or code generation), unless user asks for detail."

const PARAGRAPH_PATTERN =
  /You MUST answer concisely with fewer than \d+ lines \([^)]*\), unless user asks for detail\./g
const FOOTER_PATTERN =
  /You MUST answer concisely with fewer than \d+ lines of text \([^)]*\), unless user asks for detail\./g

export default {
  id: "opencode-pf.response-rule",
  async setup(ctx) {
    const registration = await ctx.session.hook("context", (event) => {
      event.system = event.system.map((part) => {
        if (part.type !== "text" || !part.text) return part
        return {
          ...part,
          text: part.text
            .replaceAll(PARAGRAPH_PATTERN, RESPONSE_RULE_PARAGRAPH)
            .replaceAll(FOOTER_PATTERN, RESPONSE_RULE_FOOTER),
        }
      })
    })
    return () => void registration.dispose()
  },
}