from decimal import Decimal

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0021_reservation_cancellation_reason'),
    ]

    operations = [
        migrations.CreateModel(
            name='SystemSetting',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('commission_percentage', models.DecimalField(decimal_places=2, default=Decimal('10.00'), help_text='Platform commission percentage charged on parking revenue.', max_digits=5)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
