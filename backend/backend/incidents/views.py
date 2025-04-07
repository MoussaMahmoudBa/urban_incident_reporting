from rest_framework import generics, status
from rest_framework.response import Response
from .models import Incident, OfflineIncident
from .serializers import IncidentSerializer, OfflineIncidentSerializer
from rest_framework.permissions import IsAuthenticated

class IncidentListCreateView(generics.ListCreateAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class IncidentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer

class SyncOfflineIncidentsView(generics.CreateAPIView):
    queryset = OfflineIncident.objects.all()
    serializer_class = OfflineIncidentSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        offline_incidents = OfflineIncident.objects.filter(user=request.user, is_synced=False)
        for incident in offline_incidents:
            Incident.objects.create(
                user=incident.user,
                incident_type=incident.incident_type,
                description=incident.description,
                photo=incident.photo_path,
                audio=incident.audio_path,
                location=f"POINT({incident.longitude} {incident.latitude})",
            )
            incident.is_synced = True
            incident.save()
        return Response({"status": "success"}, status=status.HTTP_200_OK)


class SyncOfflineIncidentsView(generics.CreateAPIView):
    queryset = OfflineIncident.objects.all()
    serializer_class = OfflineIncidentSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        offline_incidents = OfflineIncident.objects.filter(user=request.user, is_synced=False)
        for incident in offline_incidents:
            Incident.objects.create(
                user=incident.user,
                incident_type=incident.incident_type,
                description=incident.description,
                photo=incident.photo_path,
                audio=incident.audio_path,
                location=f"POINT({incident.longitude} {incident.latitude})",
            )
            incident.is_synced = True
            incident.save()
        return Response({"status": "success"}, status=status.HTTP_200_OK)