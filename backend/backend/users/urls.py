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
)

urlpatterns = [
    # Authentification JWT
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Gestion utilisateurs
    path('register/', UserRegisterView.as_view(), name='user-register'),
    path('users/', UserListCreateView.as_view(), name='user-list'),
    path('users/me/', current_user, name='current-user'),
    path('users/<int:pk>/', UserDetailView.as_view(), name='user-detail'),
    
    # Biométrie
    path('users/biometric-login/', biometric_login, name='biometric-login'),
    path('users/register-biometric/', register_biometric, name='register-biometric'),
    
    # Admin (facultatif)
    path('admin/users/', UserListCreateView.as_view(), name='admin-user-list'),
]