from django.db import models
from users.models import CustomUser

class Incident(models.Model):
    INCIDENT_TYPES = [
        ('fire', 'Fire'),
        ('accident', 'Accident'),
        ('theft', 'Theft'),
        ('other', 'Other'),
    ]

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='incidents')
    incident_type = models.CharField(max_length=50, choices=INCIDENT_TYPES)
    description = models.TextField()
    photo = models.ImageField(upload_to='incident_photos/', blank=True, null=True)
    location = models.CharField(max_length=255)  # Tu peux utiliser des champs plus précis comme PointField si nécessaire
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.incident_type} reported by {self.user.username}"