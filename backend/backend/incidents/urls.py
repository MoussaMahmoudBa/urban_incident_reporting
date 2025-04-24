from django.urls import path
from .views import IncidentListCreateView, IncidentDetailView, SyncOfflineIncidentsView, IncidentListView, IncidentStatsView

urlpatterns = [
    path('', IncidentListCreateView.as_view(), name='incident-list-create'),
    path('all/', IncidentListView.as_view(), name='incident-list-admin'),
    path('<int:pk>/', IncidentDetailView.as_view(), name='incident-detail'),
    path('sync/', SyncOfflineIncidentsView.as_view(), name='sync-offline-incidents'),
    path('stats/', IncidentStatsView.as_view(), name='incident-stats'),  

]