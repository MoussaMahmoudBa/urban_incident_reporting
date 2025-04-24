from rest_framework.permissions import BasePermission

class IsAdminUser(BasePermission):
    """
    Vérifie que l'utilisateur est un administrateur
    """
    def has_permission(self, request, view):
        return bool(
            request.user and 
            request.user.is_authenticated and 
            request.user.role == 'admin' and
            request.user.is_active  
            )
class IsCitizenUser(BasePermission):
    """
    Vérifie que l'utilisateur est un citoyen
    """
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'citizen'