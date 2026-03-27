"""WebSocket event handlers package.

Importing this package registers all SocketIO event handlers with the
``socketio`` singleton in ``app.extensions``.
"""

from app.ws import events  # noqa: F401 – side-effect: registers handlers

__all__ = ["events"]
