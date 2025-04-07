from django.db import models
from django.contrib.gis.db import models as gis_models  # Nouvel import
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
    audio = models.FileField(upload_to='incident_audio/', blank=True, null=True)  # Nouveau champ
    location = gis_models.PointField()  # Remplace CharField par PointField
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.incident_type} reported by {self.user.username}"

class OfflineIncident(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    incident_type = models.CharField(max_length=50)
    description = models.TextField()
    photo_path = models.CharField(max_length=255, blank=True)
    audio_path = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    is_synced = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Offline {self.incident_type} (Synced: {self.is_synced})"