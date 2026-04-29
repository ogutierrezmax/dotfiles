# 🛡️ Segurança e Proteção

> Diretrizes e práticas recomendadas para garantir a integridade e privacidade das configurações do sistema.

Este diretório centraliza a documentação de segurança do repositório de dotfiles, abordando desde o gerenciamento de segredos até a proteção contra vazamentos de dados em interações com IAs.

---

## 🛠️ Pilares de Segurança

### 1. Gerenciamento de Segredos
**Nunca** armazene senhas, tokens de API ou chaves privadas diretamente nos arquivos versionados.
- Use arquivos `.local` ou `.env` que estejam listados no `.gitignore`.
- Utilize ferramentas de criptografia ou gerenciadores de segredos se necessário.

### 2. Permissões de Arquivo
Garanta que arquivos sensíveis (como chaves SSH ou configs de banco de dados) tenham permissões restritas.
```bash
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.gnupg
```

### 3. Auditoria de Configurações (AI Guardian)
Este repositório utiliza padrões de anotação para orientar agentes de IA sobre o que é seguro editar.
- `SECURITY NOTE`: Avisos sobre implicações de segurança.
- `DANGER ZONE`: Seções críticas que não devem ser alteradas sem revisão humana.
- `NEVER`: Instruções explícitas para a IA ignorar ou não modificar.

---

## 🗺️ Documentos Adicionais
- [Guia de Gerenciamento de Segredos](secrets.md) (Em breve)
- [Políticas de Acesso SSH](ssh.md) (Em breve)

---

> [!IMPORTANT]
> Se você encontrar qualquer vulnerabilidade ou segredo exposto acidentalmente no histórico do Git, realize o purge imediato usando `git filter-repo` ou ferramentas similares e rotacione as credenciais.
