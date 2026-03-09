# Optimizador Universal de Notebooks

Herramienta de diagnóstico y optimización para notebooks con **Windows 10/11**.  
Escrita en PowerShell 5.1 puro — no requiere instalación de software adicional ni conexión a internet.

---

## ¿Qué hace?

| Módulo | Descripción |
|--------|-------------|
| **1 — Diagnóstico** | CPU, RAM, batería, disco (SSD/HDD/NVMe), WiFi, temperatura |
| **2 — Limpieza** | Archivos temporales, caché de navegadores, papelera, logs, hibernación |
| **3 — Aplicaciones** | Programas de inicio, software no deseado (PUPs), plan de energía, actualizaciones |
| **4 — Cuellos de botella** | Throttling térmico, RAM insuficiente, HDD mecánico, fragmentación |
| **5 — Reporte** | Puntaje de salud (0–100), recomendaciones priorizadas, 4 archivos en el Escritorio |
| **6 — UX/Diálogos** | Guía paso a paso en lenguaje simple, avisos de riesgo, confirmaciones |

---

## Requisitos

- Windows 10 o Windows 11
- PowerShell 5.1 o superior (incluido por defecto en Windows 10/11)
- Permisos de administrador (el script los solicita automáticamente)
- **No requiere internet**

---

## Cómo ejecutar

### Opción A — Más fácil (clic derecho)
1. Abrí la carpeta `Optimizador Universal`
2. Hacé clic derecho sobre `main.ps1`
3. Elegí **"Ejecutar con PowerShell"**
4. Si aparece "¿Desea permitir que esta aplicación haga cambios?", hacé clic en **Sí**

### Opción B — Desde la terminal
```powershell
# Abrí PowerShell como Administrador y ejecutá:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
cd "c:\Proyectos\Optimizador Universal"
.\main.ps1
```

### Opción C — Acceso directo permanente
1. Hacé clic derecho en `main.ps1` → **Crear acceso directo**
2. Hacé clic derecho en el acceso directo → **Propiedades**
3. En "Destino" ponés:  
   `powershell.exe -ExecutionPolicy Bypass -File "c:\Ruta\A\main.ps1"`
4. En "Inicio de sesión" → **Ejecutar como administrador**

---

## Estructura de archivos

```
Optimizador Universal\
├── main.ps1                            ← EJECUTAR ESTE ARCHIVO
└── modules\
    ├── Helper-Functions.ps1            ← Funciones compartidas
    ├── Show-UserInterface.ps1          ← Módulo 6: UX y diálogos
    ├── Get-SystemDiagnostics.ps1       ← Módulo 1: Diagnóstico
    ├── Invoke-SystemCleanup.ps1        ← Módulo 2: Limpieza
    ├── Get-AppAndPowerAnalysis.ps1     ← Módulo 3: Aplicaciones
    ├── Get-BottleneckAnalysis.ps1      ← Módulo 4: Cuellos de botella
    └── Write-SystemReport.ps1          ← Módulo 5: Reportes
```

---

## Archivos generados

Al terminar, se crea en el Escritorio una carpeta llamada  
`Reporte_OptimizacionPC_YYYYMMDD_HHMM` con 4 archivos:

| Archivo | Contenido |
|---------|-----------|
| `resumen.txt` | Explicación en lenguaje simple de todo lo realizado |
| `detalles_tecnicos.txt` | Log completo con valores técnicos (para soporte) |
| `recomendaciones.txt` | Lista priorizada: Alto / Medio / Bajo impacto |
| `captura_estado_sistema.txt` | Estado del sistema antes y después de la optimización |

---

## Garantías de seguridad

- ✅ No borra archivos del sistema ni documentos personales
- ✅ Toda limpieza requiere confirmación explícita del usuario (`[S/N]`)
- ✅ Las acciones de mayor riesgo muestran advertencia detallada antes de proceder
- ✅ No realiza llamadas a internet
- ✅ No instala software adicional
- ✅ Cada módulo puede saltarse independientemente

---

## Solución de problemas

**"No se puede cargar el archivo porque la ejecución de scripts está deshabilitada"**  
→ Ejecutá PowerShell como Administrador y corré:  
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**El script se cierra inmediatamente**  
→ Asegurate de ejecutarlo haciendo clic derecho → "Ejecutar con PowerShell", no doble clic.

**"No se encontró el módulo X"**  
→ Verificá que la carpeta `modules\` esté en el mismo directorio que `main.ps1` y que tenga todos los archivos.

---

*Optimizador Universal de Notebooks — Desarrollado con PowerShell 5.1, compatible con Windows 10/11*
