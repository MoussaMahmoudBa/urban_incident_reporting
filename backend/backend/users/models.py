from django.contrib.auth.models import AbstractUser
from django.db import models
from django.contrib.auth.hashers import make_password
import os

def user_profile_picture_path(instance, filename):
    """Génère un chemin unique pour les photos de profil"""
    return f'profile_pictures/user_{instance.id}/{filename}'

class CustomUser(AbstractUser):

    ROLE_CHOICES = [
        ('citizen', 'Citoyen'),
        ('admin', 'Administrateur'),
    ]


    phone_number = models.CharField(
        max_length=15, 
        blank=True, 
        null=True,
        verbose_name='Numéro de téléphone'
    )
    profile_picture = models.ImageField(
        upload_to=user_profile_picture_path,
        blank=True,
        null=True,
        verbose_name='Photo de profil'
    )
    biometric_token = models.CharField(
        max_length=255, 
        blank=True, 
        null=True,
        verbose_name='Token biométrique'
    )
    face_embedding = models.BinaryField(
        null=True, 
        blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='citizen')
    def set_biometric_token(self, raw_token):
        """Hash et stocke le token biométrique"""
        if raw_token:
            self.biometric_token = make_password(raw_token)
            self.save(update_fields=['biometric_token'])


    def check_biometric_token(self, raw_token):
        """Vérifie le token biométrique"""
        from django.contrib.auth.hashers import check_password
        return bool(
            self.biometric_token and 
            raw_token and 
            check_password(raw_token, self.biometric_token))

    def save(self, *args, **kwargs):
        """Gestion des anciennes images et sauvegarde optimisée"""
        if self.pk:
            try:
                old = CustomUser.objects.get(pk=self.pk)
                if (old.profile_picture and 
                    old.profile_picture != self.profile_picture):
                    old.profile_picture.delete(save=False)
            except CustomUser.DoesNotExist:
                pass

        if self.role == 'admin':
            self.is_staff = True
            self.is_active = True
            
                 
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        """Nettoyage des fichiers à la suppression"""
        if self.profile_picture:
            self.profile_picture.delete(save=False)
        super().delete(*args, **kwargs)


    
    def create_user(self, username, email, password, **extra_fields):
            """Crée et enregistre un utilisateur avec le mot de passe hashé"""
            if not email:
                raise ValueError("L'email doit être fourni")
            
            user = self.model(
                username=username,
                email=self.normalize_email(email),
                **extra_fields
            )
            user.set_password(password)
            user.save(using=self._db)
            return user
    
    def has_module_perms(self, app_label):
        return self.role == 'admin' or super().has_module_perms(app_label)
    
    def has_perm(self, perm, obj=None):
        return self.role == 'admin' or super().has_perm(perm, obj)


    def is_admin(self):
        return self.role == 'admin' and self.is_active

    def __str__(self):
        return f"{self.username} ({self.email or 'pas d\'email'})"

    class Meta:
        verbose_name = 'Utilisateur'
        verbose_name_plural = 'Utilisateurs'
        ordering = ['-date_joined']
        indexes = [
            models.Index(fields=['username']),
            models.Index(fields=['email']),
        ]