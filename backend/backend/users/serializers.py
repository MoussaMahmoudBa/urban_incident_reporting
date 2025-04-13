from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from django.core.validators import FileExtensionValidator, validate_email
from .models import CustomUser

class UserRegisterSerializer(serializers.ModelSerializer):
    """Serializer pour l'inscription"""
    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={'input_type': 'password'},
        required=True
    )

    password2 = serializers.CharField(  # Nouveau champ
        write_only=True,
        style={'input_type': 'password'},
        required=True
    )

    profile_picture = serializers.ImageField(
        required=False,
        validators=[FileExtensionValidator(['jpg', 'jpeg', 'png'])]
    )

    class Meta:
        model = CustomUser
        fields = [
            'username', 
            'email', 
            'password',
            'password2',  
            'phone_number',
            'profile_picture',
            'role'
        ]
        extra_kwargs = {
            'email': {
                'required': True,
                'validators': [validate_email]
            },
            'username': {
                'min_length': 4,
                'required': True
            },
            'phone_number': {
                'required': False,
                'allow_blank': True
            },
            'role': {'read_only': True},
            
        }

    def validate_email(self, value):
        if CustomUser.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Un utilisateur avec cet email existe déjà.")
        return value.strip().lower()
    
    def validate(self, data):
        if not data.get('username') and not self.context.get('request').user.is_authenticated:
            raise serializers.ValidationError(
                "Le nom d'utilisateur est requis pour les utilisateurs non authentifiés."
            )
        return data

    def validate_username(self, value):
        if CustomUser.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur est déjà pris.")
        return value.strip()

    def create(self, validated_data):
        validated_data.pop('password2')  # On retire le champ de confirmation
        profile_picture = validated_data.pop('profile_picture', None)
        user = CustomUser.objects.create_user(**validated_data)
        
        if profile_picture:
            user.profile_picture = profile_picture
            user.save()
            
        return user

class UserSerializer(serializers.ModelSerializer):
    """Serializer principal pour les utilisateurs"""
    profile_picture = serializers.SerializerMethodField()

    class Meta:
        model = CustomUser
        fields = [
            'id',
            'username',
            'email',
            'phone_number',
            'profile_picture',
            'date_joined',
            'last_login',
            'biometric_token',
            'role'
        ]
        extra_kwargs = {
            'biometric_token': {'write_only': True},
            'date_joined': {'read_only': True},
            'last_login': {'read_only': True}
        }

    def get_profile_picture(self, obj):
        if obj.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.profile_picture.url)
        return None

class BiometricAuthSerializer(serializers.Serializer):
    """Serializer pour l'authentification biométrique"""
    biometric_token = serializers.CharField(
        max_length=255,
        required=True
    )
    

    def validate(self, data):
        return data