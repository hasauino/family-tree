# Generated by Django 2.2.7 on 2019-11-27 20:02

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0017_auto_20191127_0326'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='birth_date',
            field=models.DateField(blank=True,
                                   null=True,
                                   verbose_name='تاريخ الميلاد'),
        ),
        migrations.AlterField(
            model_name='user',
            name='font_size',
            field=models.IntegerField(default=100, verbose_name='حجم الخط'),
        ),
        migrations.AlterField(
            model_name='user',
            name='theme',
            field=models.CharField(choices=[('DEFAULT', 'الإفتراضي'),
                                            ('BABA', 'الواضح'),
                                            ('MODERN', 'الحديث')],
                                   default='DEFAULT',
                                   max_length=10,
                                   verbose_name='النمط'),
        ),
    ]
