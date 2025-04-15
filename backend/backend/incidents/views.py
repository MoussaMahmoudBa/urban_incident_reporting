from rest_framework import generics, status
from rest_framework.views import APIView
from django.db.models import Count
from django.contrib.auth import get_user_model
from datetime import datetime, timedelta
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from .models import Incident, OfflineIncident
from .serializers import IncidentSerializer, OfflineIncidentSerializer
from django.contrib.gis.geos import Point
User = get_user_model()


class IncidentStatsView(APIView):
    permission_classes = [IsAdminUser]
    
    def get(self, request):
        # Statistiques de base
        total_incidents = Incident.objects.count()
        
        # Incidents par type
        incidents_by_type = Incident.objects.values('incident_type') \
            .annotate(count=Count('id')) \
            .order_by('-count')
        
        # Incidents par utilisateur (top 5)
        top_users = User.objects.filter(incidents__isnull=False) \
            .annotate(incident_count=Count('incidents')) \
            .order_by('-incident_count')[:5]
        
        # Incidents par période (7 derniers jours)
        date_threshold = datetime.now() - timedelta(days=7)
        incidents_last_7_days = Incident.objects.filter(
            created_at__gte=date_threshold
        ).extra({
            'date': "date(created_at)"
        }).values('date').annotate(
            count=Count('id')
        ).order_by('date')
        
        # Préparation des données pour le frontend
        stats = {
            'total_incidents': total_incidents,
            'incidents_by_type': list(incidents_by_type),
            'top_users': [
                {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'incident_count': user.incident_count
                }
                for user in top_users
            ],
            'incidents_last_7_days': list(incidents_last_7_days),
            'recent_incidents': IncidentSerializer(
                Incident.objects.all().order_by('-created_at')[:5],
                many=True
            ).data
        }
        
        return Response(stats)





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