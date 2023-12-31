# Generated by Django 2.2.7 on 2019-11-26 04:11

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0003_auto_20191126_0403'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='email',
            field=models.EmailField(blank=True,
                                    error_messages={
                                        'invalid': 'Enter a valid value',
                                        'required': 'الرجاء تعبئة هذا الحقل'
                                    },
                                    max_length=254,
                                    null=True,
                                    unique=True),
        ),
    ]
