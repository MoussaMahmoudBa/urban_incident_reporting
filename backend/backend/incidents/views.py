from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from .models import Incident, OfflineIncident
from .serializers import IncidentSerializer, OfflineIncidentSerializer
from django.contrib.gis.geos import Point

class IncidentListCreateView(generics.ListCreateAPIView):
    serializer_class = IncidentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Ne retourne que les incidents de l'utilisateur connecté
        return Incident.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        # Convertit les coordonnées en Point si nécessaire
        location = serializer.validated_data.get('location')
        if isinstance(location, str):
            try:
                lat, lon = map(float, location.split(','))
                serializer.validated_data['location'] = Point(lon, lat)
            except (ValueError, AttributeError):
                pass
        serializer.save(user=self.request.user)

class IncidentListView(generics.ListAPIView):
    serializer_class = IncidentSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        return Incident.objects.all().order_by('-created_at')

class IncidentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = IncidentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Ne retourne que les incidents de l'utilisateur connecté
        return Incident.objects.filter(user=self.request.user)

class SyncOfflineIncidentsView(generics.CreateAPIView):
    queryset = OfflineIncident.objects.all()
    serializer_class = OfflineIncidentSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        offline_incidents = OfflineIncident.objects.filter(user=request.user, is_synced=False)
        
        created_count = 0
        for incident in offline_incidents:
            Incident.objects.create(
                user=incident.user,
                incident_type=incident.incident_type,
                description=incident.description,
                photo=incident.photo_path,
                audio=incident.audio_path,
                location=Point(incident.longitude, incident.latitude),
            )
            incident.is_synced = True
            incident.save()
            created_count += 1
            
        return Response({
            "status": "success",
            "synced_incidents": created_count
        }, status=status.HTTP_200_OK)