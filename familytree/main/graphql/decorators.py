"""Auth-gating decorators for GraphQL mutation resolvers, shared across the
schema modules (kept separate from schema.py to avoid import cycles)."""


def authenticated_only(function):
    def wrapper(root, info, **args):
        if not info.context.user.is_authenticated:
            raise Exception("Access Denied! you must be a logged in user to access this API")
        return function(root, info, **args)

    return wrapper


def staff_only(function):
    def wrapper(root, info, **args):
        if not info.context.user.is_staff:
            raise Exception("Access Denied! you must be a logged in user to access this API")
        return function(root, info, **args)

    return wrapper
