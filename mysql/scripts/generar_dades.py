import mysql.connector
import random
from datetime import datetime, timedelta
from decimal import Decimal

conn = mysql.connector.connect(
    host="localhost",
    port=3306,
    user="root",
    password="root1234",
    database="energiadb"
)

cursor = conn.cursor(dictionary=True)

cursor.execute("""
    SELECT fecha, consumo, generacion, hora_dia, idexcel
    FROM generacion_energia
    WHERE consumo IS NOT NULL
      AND generacion IS NOT NULL
    ORDER BY RAND()
    LIMIT 200
""")

dades_base = cursor.fetchall()

if not dades_base:
    print("No hi ha dades base en generacion_energia.")
    exit()

registres_a_crear = 1000000

for _ in range(registres_a_crear):
    fila = random.choice(dades_base)

    fecha_base = fila["fecha"] or datetime.now()
    nova_fecha = fecha_base + timedelta(days=random.randint(1, 365))

    consum_base = float(fila["consumo"])
    generacio_base = float(fila["generacion"])

    nou_consum = consum_base * random.uniform(0.85, 1.15)
    nova_generacio = generacio_base * random.uniform(0.85, 1.15)

    hora_dia = nova_fecha.hour
    idexcel = fila["idexcel"]

    cursor.execute("""
        INSERT INTO generacion_energia
            (fecha, consumo, generacion, hora_dia, idexcel)
        VALUES
            (%s, %s, %s, %s, %s)
    """, (
        nova_fecha.strftime("%Y-%m-%d %H:%M:%S"),
        round(nou_consum, 3),
        round(nova_generacio, 3),
        hora_dia,
        idexcel
    ))

conn.commit()

print(f"{registres_a_crear} registres aleatoris creats correctament.")

cursor.close()
conn.close()
