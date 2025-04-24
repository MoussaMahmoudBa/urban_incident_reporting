from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from .views import (
    UserRegisterView,
    UserListCreateView,
    UserDetailView,
    current_user,
    biometric_login,
    register_biometric,
    login_view,
    UserStatsView,
    toggle_user_status,
    AdminRegisterView
)

urlpatterns = [
    # Authentification JWT
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Gestion utilisateurs
    path('register/', UserRegisterView.as_view(), name='user-register'),
    path('', UserListCreateView.as_view(), name='user-list'),
    path('me/', current_user, name='current-user'),
    path('<int:pk>/', UserDetailView.as_view(), name='user-detail'),
    
    # Biométrie
    path('biometric-login/', biometric_login, name='biometric-login'),
    path('register-biometric/', register_biometric, name='register-biometric'),
    
    # Admin (facultatif)
    path('admin/users/', UserListCreateView.as_view(), name='admin-user-list'),
    path('admin/register/', AdminRegisterView.as_view(), name='admin-register'),



     # Statistiques et gestion admin
    path('stats/', UserStatsView.as_view(), name='user-stats'),
    path('<int:user_id>/toggle-status/', toggle_user_status, name='toggle-user-status'),

     # Authentification personnalisée
    path('login/', login_view, name='login'),
]