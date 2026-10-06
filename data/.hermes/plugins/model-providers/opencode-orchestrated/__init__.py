"""OpenCode Orchestrated model provider profile.

Provides local ACP bridge to OpenCode CLI without requiring API keys directly in Hermes.
Includes dynamic discovery of free models and renders a '· free' note in the model picker.
"""

from __future__ import annotations

import os
from typing import Any

from providers import register_provider
from providers.base import ProviderProfile


class OpenCodeACPProfile(ProviderProfile):
    """OpenCode CLI ACP provider — external process via stdio, no external API keys needed."""

    def create_client(self, **client_kwargs: Any) -> Any:
        from .client import OpenCodeACPClient

        return OpenCodeACPClient(**client_kwargs)

    def discover_models(self, **kwargs: Any) -> list[dict[str, Any]] | None:
        """Annotated model catalog for the interactive picker ('hermes model').

        Models that are free will display the '· free' column in the picker menu.
        """
        from .client import get_opencode_models_catalog

        catalog = get_opencode_models_catalog()
        if not catalog:
            return None

        rows: list[dict[str, Any]] = []
        for m in catalog:
            row: dict[str, Any] = {
                "id": m["id"],
                "label": m["name"],
            }
            if m.get("is_free"):
                row["note"] = "free"
            rows.append(row)
        return rows

    def fetch_models(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: float = 15.0,
    ) -> list[str] | None:
        """Return model IDs with free models prioritized at the top."""
        client = self.create_client()
        return client.list_models(timeout_seconds=timeout) or list(self.fallback_models)

    def setup_status(self, **kwargs: Any) -> dict[str, Any]:
        return {
            "available": True,
            "logged_in": True,
            "detail": "OpenCode local ACP binary verified",
        }


_default_binary = os.path.expanduser("~/.opencode/bin/opencode")
if not (os.path.isfile(_default_binary) and os.access(_default_binary, os.X_OK)):
    _default_binary = "opencode"

opencode_orchestrated = OpenCodeACPProfile(
    name="opencode-orchestrated",
    aliases=(
        "opencode-orchestred",
        "opencode orchestred",
        "opencode_orchestrated",
        "opencode-orchestrator",
        "opencode-acp",
    ),
    display_name="OpenCode Orchestrated",
    description="OpenCode CLI agent via local ACP (Free models annotated)",
    api_mode="chat_completions",
    auth_type="external_process",
    base_url="acp://opencode",
    process_command=_default_binary,
    process_args=("acp",),
    process_command_env_vars=("HERMES_OPENCODE_ACP_COMMAND", "OPENCODE_CLI_PATH"),
    process_args_env_var="HERMES_OPENCODE_ACP_ARGS",
    fallback_models=(
        "opencode/big-pickle",
        "big pickle free",
    ),
    model_aliases={
        "big pickle free": "opencode/big-pickle",
        "big-pickle-free": "opencode/big-pickle",
        "big pickle": "opencode/big-pickle",
        "big-pickle": "opencode/big-pickle",
        "pickle": "opencode/big-pickle",
    },
)

register_provider(opencode_orchestrated)
