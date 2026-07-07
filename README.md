# GymPro Access

Conector local para abrir molinetes TangoAccess desde GymPro.

## Funcionamiento

```text
GymPro -> http://127.0.0.1:8787/open -> C:\TangoAccess\abrir.exe -> molinete abre
```

El molinete no valida alumnos. Solo abre.

La validacion de DNI, tenant, alumno activo y cuota paga la hace GymPro. Si GymPro autoriza, llama al conector local.

## Descargar instalador

En la PC del gym:

```powershell
Invoke-WebRequest -Uri "https://github.com/Agenor-IT/gympro-access/releases/latest/download/GymProAccessInstaller.zip" -OutFile "$env:USERPROFILE\Downloads\GymProAccessInstaller.zip"
```

Tambien se puede clonar el repo:

```powershell
git clone https://github.com/Agenor-IT/gympro-access.git
cd gympro-access
```

## Instalar

1. Confirmar que existe:

```text
C:\TangoAccess\abrir.exe
```

2. Ejecutar como administrador:

```text
install.bat
```

3. Presionar Enter en los valores por defecto, salvo que el tecnico del molinete haya indicado otra ruta.

El instalador crea:

```text
C:\GymProAccess
```

La carpeta descargada/clonada no es la instalacion final. La instalacion final queda en `C:\GymProAccess`.

## Probar instalacion

Estado del gateway:

```text
C:\GymProAccess\test-health.bat
```

Debe mostrar:

```text
executableExists: True
workingDirectoryExists: True
tokenConfigured: True
```

Apertura del molinete:

```text
C:\GymProAccess\test-open.bat
```

Debe mostrar:

```text
ok: true
status: open_command_sent
```

Si el molinete abre, la integracion fisica funciona.

Si `C:\TangoAccess\abrir.exe` abre con doble click pero `test-open.bat` no abre, reinstalar con la ultima version del conector. El gateway ejecuta `abrir.exe` usando `C:\TangoAccess` como carpeta de trabajo.

## Configurar Chrome

Abrir:

```text
C:\GymProAccess\CONFIGURAR-NAVEGADOR.txt
```

Luego:

1. Abrir GymPro en Chrome.
2. Iniciar sesion.
3. Presionar `F12`.
4. Ir a `Console`.
5. Si Chrome muestra advertencia de pegado, escribir:

```text
allow pasting
```

6. Presionar Enter.
7. Pegar las lineas de `CONFIGURAR-NAVEGADOR.txt`.

La pagina se recarga por `location.reload()`. Eso es correcto.

## Verificar Chrome

En la consola:

```js
localStorage.getItem("gympro.tangoAccess.enabled")
```

Debe devolver:

```text
"true"
```

```js
localStorage.getItem("gympro.tangoAccess.url")
```

Debe devolver:

```text
"http://127.0.0.1:8787/open"
```

```js
localStorage.getItem("gympro.tangoAccess.token")
```

Debe devolver un valor que empieza con:

```text
"gympro-"
```

## Uso diario

1. Abrir GymPro.
2. Ir a Home.
3. Click en `Abrir visor`.
4. Mover esa ventana al monitor del alumno.
5. El alumno ingresa DNI.
6. Si GymPro autoriza, el molinete abre.

## Si la PC se reinicia

Si el instalador no pudo crear la tarea de inicio automatico, iniciar manualmente:

```text
C:\GymProAccess\start-gateway.bat
```

## Diagnostico rapido

- `test-open.bat` no abre: revisar `C:\TangoAccess\abrir.exe` con el proveedor del molinete.
- `test-open.bat` abre pero GymPro no abre: revisar `CONFIGURAR-NAVEGADOR.txt` y `localStorage`.
- GymPro deniega: revisar DNI, cuota, alumno o tenant en GymPro.
