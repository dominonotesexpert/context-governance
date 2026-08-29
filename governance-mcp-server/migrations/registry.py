"""Registry of (from_version, to_version) -> upgrader callables."""

from __future__ import annotations

from typing import Callable, Dict, Tuple

from . import v1_to_v2

Upgrader = Callable[[dict], dict]

REGISTRY: Dict[Tuple[int, int], Upgrader] = {
    (1, 2): v1_to_v2.upgrade,
}
