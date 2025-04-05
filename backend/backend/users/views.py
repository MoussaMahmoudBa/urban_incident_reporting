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

User = get_user_model()

class UserRegisterView(generics.CreateAPIView):
    """Inscription publique des utilisateurs"""
    queryset = User.objects.all()
    serializer_class = UserRegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {
                    'status': 'error',
                    'errors': serializer.errors,
                    'message': 'Validation failed'
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
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
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]

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
        if self.request.method == 'DELETE':
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
    """Enregistrement biométrique"""
    print(f"Requête reçue - User: {request.user}")  # Log
    serializer = BiometricAuthSerializer(data=request.data)

    serializer = BiometricAuthSerializer(
        data=request.data,
        context={'request': request}
        )
    if not serializer.is_valid():
        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        request.user.set_biometric_token(
            serializer.validated_data['biometric_token']
        )
        return Response({'status': 'success'})
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )