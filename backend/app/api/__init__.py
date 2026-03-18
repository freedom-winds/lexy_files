"""Register all API blueprints under /api/v1."""


def register_blueprints(app):
    from app.api.auth import auth_bp
    from app.api.files import files_bp
    from app.api.devices import devices_bp
    from app.api.transfers import transfers_bp
    from app.api.admin import admin_bp

    app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')
    app.register_blueprint(files_bp, url_prefix='/api/v1/files')
    app.register_blueprint(devices_bp, url_prefix='/api/v1/devices')
    app.register_blueprint(transfers_bp, url_prefix='/api/v1/transfers')
    app.register_blueprint(admin_bp, url_prefix='/api/v1/admin')
