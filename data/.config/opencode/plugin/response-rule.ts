// Ajuste do "limite de linhas" da resposta no system prompt do opencode.
// EDITE AQUI as duas constantes conforme sua vontade e reinicie o opencode.
// Texto inicial = seed byte a byte idêntico ao template default.txt v1.18.30.
const RESPONSE_RULE_PARAGRAPH =
  "You MUST answer concisely with fewer than 8 lines (not including tool use or code generation), unless user asks for detail."
const RESPONSE_RULE_FOOTER =
  "You MUST answer concisely with fewer than 8 lines of text (not including tool use or code generation), unless user asks for detail."

export default async function () {
  return {
    "experimental.chat.system.transform": async (_input, output) => {
      output.system = output.system.map((part) =>
        part
          .replaceAll(
            /You MUST answer concisely with fewer than \d+ lines \([^)]*\), unless user asks for detail\./g,
            RESPONSE_RULE_PARAGRAPH,
          )
          .replaceAll(
            /You MUST answer concisely with fewer than \d+ lines of text \([^)]*\), unless user asks for detail\./g,
            RESPONSE_RULE_FOOTER,
          ),
      )
    },
  }
}