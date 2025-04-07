# Generated by Django 5.1.7 on 2025-04-06 18:03

import django.contrib.gis.db.models.fields
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('incidents', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='incident',
            name='audio',
            field=models.FileField(blank=True, null=True, upload_to='incident_audio/'),
        ),
        migrations.AlterField(
            model_name='incident',
            name='location',
            field=django.contrib.gis.db.models.fields.PointField(srid=4326),
        ),
        migrations.CreateModel(
            name='OfflineIncident',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('incident_type', models.CharField(max_length=50)),
                ('description', models.TextField()),
                ('photo_path', models.CharField(blank=True, max_length=255)),
                ('audio_path', models.CharField(blank=True, max_length=255)),
                ('latitude', models.FloatField()),
                ('longitude', models.FloatField()),
                ('is_synced', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
