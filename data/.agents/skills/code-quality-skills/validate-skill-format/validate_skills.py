#!/usr/bin/env python3
"""
validate_skills.py — Valida frontmatter de todos os SKILL.md.

Regras imutáveis:
  1. L1: exatamente "---"
  2. L2: name: "<nome>"  (com aspas duplas, nome não vazio)
  3. L3: description: "  (começa com aspas duplas)
  4. Existe 2º "---" de fechamento
  5. Linha anterior ao 2º "---" termina com '"'

Uso:
    python3 validate_skills.py
    python3 validate_skills.py /caminho/skills
    python3 validate_skills.py --help
"""

import re
import sys
from pathlib import Path

SKILLS_DIR = Path(__file__).resolve().parent.parent.parent


def find_skill_files(root: Path) -> list[Path]:
    if not root.is_dir():
        print(f"ERRO: diretório não encontrado: {root}", file=sys.stderr)
        sys.exit(1)
    return sorted(root.rglob("SKILL.md"))


def validate_file(filepath: Path) -> dict:
    result = {"filepath": filepath, "errors": [], "suggestions": []}

    raw_lines = filepath.read_text(encoding="utf-8", errors="replace").splitlines()

    if not raw_lines:
        result["errors"].append("Arquivo vazio")
        return result

    lines = [ln.strip() for ln in raw_lines]

    # ---- L1 ----
    if lines[0] != "---":
        result["errors"].append(
            f"L1: deve ser exatamente '---', encontrado {raw_lines[0]!r}"
        )
        return result

    if len(lines) < 4:
        result["errors"].append(
            f"Poucas linhas ({len(lines)}) — frontmatter incompleto"
        )
        return result

    # ---- L2 ----
    l2_raw = raw_lines[1]
    l2 = lines[1]
    skill_name = ""

    name_match = re.match(r'^name: "(.+)"$', l2)
    if name_match:
        skill_name = name_match.group(1).strip()
        if not skill_name:
            result["errors"].append("L2: nome não pode ser vazio (name: \"\")")
    else:
        if l2.startswith("name: "):
            val = l2[len("name: "):]
            if val == '""':
                result["errors"].append("L2: nome não pode ser vazio")
            elif val.startswith('"') and not val.endswith('"'):
                result["errors"].append(
                    f"L2: aspas abertas mas não fechadas, encontrado {l2_raw!r}"
                )
                result["suggestions"].append("L2: feche as aspas duplas no final do nome")
            elif val.startswith("'"):
                result["errors"].append(
                    f"L2: usar aspas simples em vez de duplas, encontrado {l2_raw!r}"
                )
                result["suggestions"].append("L2: troque aspas simples por duplas")
            elif val[0] != '"':
                result["errors"].append(
                    f"L2: valor sem aspas, encontrado {l2_raw!r}"
                )
                result["suggestions"].append(
                    "L2: envolva o nome em aspas duplas (ex: name: \"skill-name\")"
                )
            else:
                result["errors"].append(
                    f"L2: formato inválido, encontrado {l2_raw!r}"
                )
        else:
            result["errors"].append(
                f"L2: deve começar com 'name: ', encontrado {l2_raw!r}"
            )

    # ---- L3 ----
    if not lines[2].startswith('description: "'):
        l3_raw = raw_lines[2]
        if lines[2].startswith("description: >"):
            result["errors"].append(
                f"L3: usa bloco YAML '>', deve usar aspas duplas inline"
            )
            result["suggestions"].append(
                "L3: troque 'description: >' por 'description: \"...' "
                "com aspas duplas na mesma linha"
            )
        elif lines[2].startswith("description: "):
            result["errors"].append(
                f"L3: valor sem aspas, encontrado {l3_raw!r}"
            )
            result["suggestions"].append(
                "L3: adicione aspas duplas após 'description: '"
            )
        else:
            result["errors"].append(
                f"L3: deve começar com 'description: \"', encontrado {l3_raw!r}"
            )

    # ---- 2º --- e linha anterior ----
    # Only look within first 50 lines to avoid matching --- in code blocks
    search_limit = min(50, len(lines))
    found_close = False
    for i in range(1, search_limit):
        if lines[i] == "---":
            prev = raw_lines[i - 1].rstrip()
            if not prev.endswith('"'):
                result["errors"].append(
                    f"L{i+1}: linha anterior (L{i}) termina sem '\"' — "
                    f"últimos caracteres: {prev[-10:]!r}"
                )
                result["suggestions"].append(
                    f"L{i}: adicione '\"' ao final da linha de descrição"
                )
            found_close = True
            break

    if not found_close:
        result["errors"].append("Nenhum '---' de fechamento encontrado nas primeiras 50 linhas")

    # ---- Sugestão: nome vs pasta ----
    if skill_name and skill_name != filepath.parent.name:
        result["suggestions"].append(
            f"Nome '{skill_name}' difere do nome da pasta '{filepath.parent.name}'"
        )

    return result


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Valida frontmatter de SKILL.md"
    )
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=SKILLS_DIR,
        help="Diretório raiz (default: skills/ junto ao script)",
    )
    args = parser.parse_args()

    files = find_skill_files(args.path)
    if not files:
        print("Nenhum arquivo SKILL.md encontrado.")
        return 0

    results = [validate_file(f) for f in files]

    valid = sum(1 for r in results if not r["errors"])
    invalid = len(results) - valid

    print(f"Escaneando {len(results)} arquivos SKILL.md...\n")

    col_w = 70
    hdr = f"{'SKILL.md':<{col_w}}  Status"
    print(hdr)
    print("-" * (col_w + 9))

    for r in results:
        rel = r["filepath"].relative_to(args.path)
        disp = str(rel)
        ok = not r["errors"]
        print(f"{disp:<{col_w}}  {'✅' if ok else '❌'}")

        for e in r["errors"]:
            print(f"  {'':>8}⚠  {e}")
        for s in r["suggestions"]:
            print(f"  {'':>8}💡  {s}")

        if r["errors"] or r["suggestions"]:
            print()

    print("-" * (col_w + 9))
    print(f"\nResumo: {valid} válidos, {invalid} com erro de {len(results)}")

    return 0 if invalid == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
