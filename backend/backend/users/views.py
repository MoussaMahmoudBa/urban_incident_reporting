from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model, authenticate
from .models import CustomUser
from .serializers import (
    UserSerializer,
    UserRegisterSerializer,
    BiometricAuthSerializer
)
from .permissions import IsAdminUser, IsCitizenUser
from rest_framework.views import APIView
from django.db.models import Count
from django.http import JsonResponse
from rest_framework.pagination import PageNumberPagination


User = get_user_model()



# Ajouter cette classe pour les statistiques utilisateurs
class UserStatsView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        # Nombre total d'utilisateurs (non admin)
        total_users = User.objects.filter(role='citizen').count()
        
        # Utilisateurs les plus actifs (avec nombre d'incidents)
        active_users = User.objects.filter(role='citizen').annotate(
            incident_count=Count('incidents')
        ).order_by('-incident_count')[:5]
        
        # Formatage des données
        active_users_data = [
            {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'incident_count': user.incident_count
            } 
            for user in active_users
        ]
        
        return Response({
            'total_users': total_users,
            'most_active_users': active_users_data
        })


# Ajouter cette vue pour activer/désactiver un utilisateur
@api_view(['PATCH'])
@permission_classes([IsAdminUser])
def toggle_user_status(request, user_id):
    try:
        user = User.objects.get(id=user_id)
        is_active = request.data.get('is_active', None)
        
        if is_active is None:
            return Response(
                {'error': 'Le champ is_active est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user.is_active = is_active
        user.save()
        
        # Invalider les tokens si désactivation
        if not is_active:
            user.auth_token_set.all().delete()
        
        return Response({
            'status': 'success',
            'is_active': user.is_active
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )


class UserRegisterView(generics.CreateAPIView):
    """Inscription publique des utilisateurs"""
    queryset = User.objects.all()
    serializer_class = UserRegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            user= serializer.save()
            refresh = RefreshToken.for_user(user)    


            return Response({  # Structure de réponse modifiée
            'tokens': {
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            'user_id': user.id,
        }, status=201)
        
        
        try:
            # Création de l'utilisateur
            user = serializer.save()
            
            # Génération des tokens
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'status': 'success',
                'user_id': user.id,
                'username': user.username,
                'email': user.email,
                'tokens': {
                    'access': str(refresh.access_token),
                    'refresh': str(refresh)
                }
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            return Response(
                {
                    'status': 'error',
                    'message': str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            
            )

class UserListCreateView(generics.ListCreateAPIView):
    """Liste et création (admin seulement)"""
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]
    pagination_class = PageNumberPagination
    def get_queryset(self):
        queryset = User.objects.all()
        exclude_admins = self.request.query_params.get('exclude_admins')
        if exclude_admins:
            queryset = queryset.filter(role='citizen')
        
        # Filtre par statut actif
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
        return queryset.order_by('-date_joined')

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
            headers=headers
        )
    
    
class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Détail utilisateur"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.request.method in ['DELETE', 'PUT', 'PATCH']:
            return [IsAdminUser()]
        return [IsAuthenticated()]

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=partial
        )
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_user(request):
    """Récupère l'utilisateur courant"""
    serializer = UserSerializer(request.user, context={'request': request})
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    """Vue de connexion améliorée avec gestion d'erreur complète"""
    username = request.data.get('username')
    password = request.data.get('password')
    
    if not username or not password:
        return Response(
            {"error": "Nom d'utilisateur et mot de passe requis"},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = authenticate(username=username, password=password)
    
    if user is None:
        return Response(
            {"error": "Identifiants invalides ou compte inexistant"},
            status=status.HTTP_401_UNAUTHORIZED
        )
    
    if not user.is_active:
        return Response(
            {"error": "Ce compte est désactivé"},
            status=status.HTTP_403_FORBIDDEN
        )
    
    refresh = RefreshToken.for_user(user)
    user_data = UserSerializer(user, context={'request': request}).data
    
    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': user_data
    })
@api_view(['POST'])
@permission_classes([AllowAny])
def biometric_login(request):
    """Authentification biométrique"""
    serializer = BiometricAuthSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    
    try:
        user = User.objects.get(
            username=serializer.validated_data['username']  # Assurez-vous que le username est requis
        )
        if user.check_biometric_token(serializer.validated_data['biometric_token']):
            refresh = RefreshToken.for_user(user)
            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh)
            })
        return Response(
            {'error': 'Token biométrique invalide'},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except User.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_biometric(request):
    try:
        token = request.data.get('biometric_token')
        if not token:
            return Response({'error': 'Token manquant'}, status=400)
            
        request.user.set_biometric_token(token)
        return Response({'status': 'success'})
    except Exception as e:
        return Response({'error': str(e)}, status=400)