GYMPRO ACCESS - GUIA DE INSTALACION

Objetivo:
Conectar GymPro con el molinete TangoAccess de la PC del gym.

Cadena de funcionamiento:
GymPro -> http://127.0.0.1:8787/open -> C:\TangoAccess\abrir.exe -> molinete abre

1. REQUISITO DEL PROVEEDOR DEL MOLINETE

Antes de instalar, confirmar que existe:

C:\TangoAccess\abrir.exe

Ese archivo lo instala el tecnico del molinete. Sin ese archivo, GymPro no puede abrir el molinete.

2. INSTALACION DEL CONECTOR GYMPRO

En la carpeta descargada o clonada del repo gympro-access:

- Click derecho sobre install.bat
- Ejecutar como administrador
- Presionar Enter en las 3 preguntas, salvo que el tecnico haya indicado otra ruta para abrir.exe

El instalador crea:

C:\GymProAccess

Si estas mirando C:\Usuarios\Usuario\gympro-access, esa es la carpeta de descarga.
La carpeta instalada real es C:\GymProAccess.

3. ADVERTENCIA DE INICIO AUTOMATICO

Si aparece:

No se pudo crear la tarea de inicio automatico

No bloquea la prueba.
Significa que, si se reinicia la PC, puede hacer falta iniciar manualmente:

C:\GymProAccess\start-gateway.bat

El gateway es el puente local entre GymPro y el molinete. Si la PC se apaga o reinicia y el gateway no vuelve a iniciar, GymPro valida el DNI pero no puede mandar la orden de apertura.

Para dejarlo permanente sin tarea programada:

- Presionar Win + R
- Escribir:

shell:startup

- Presionar Enter
- Crear un acceso directo a:

C:\GymProAccess\start-gateway-hidden.vbs

Con eso, Windows lo inicia al entrar al usuario.

4. PRUEBA DEL CONECTOR

Ejecutar:

C:\GymProAccess\test-health.bat

Resultado esperado:

executableExists: True
workingDirectoryExists: True
tokenConfigured: True

Despues ejecutar:

C:\GymProAccess\test-open.bat

Resultado esperado:

ok: true
status: open_command_sent

Si test-open.bat abre el molinete, la parte fisica esta funcionando.
Si abrir.exe abre con doble click pero test-open.bat no abre, reinstalar con la ultima version del conector.
La version corregida ejecuta abrir.exe usando C:\TangoAccess como carpeta de trabajo.

5. CONFIGURACION DE CHROME / GYMPRO

Abrir:

C:\GymProAccess\CONFIGURAR-NAVEGADOR.txt

Luego:

- Abrir GymPro en Chrome
- Iniciar sesion con el usuario del gym
- Presionar F12
- Ir a Console
- Si Chrome bloquea pegar codigo, escribir manualmente:

allow pasting

- Presionar Enter
- Pegar las lineas del archivo CONFIGURAR-NAVEGADOR.txt

Una de las lineas hace:

location.reload();

Por eso la pantalla de GymPro se recarga. Eso esta bien.

6. VERIFICACION EN CHROME

En la consola de Chrome ejecutar:

localStorage.getItem("gympro.tangoAccess.enabled")

Debe devolver:

"true"

Luego ejecutar:

localStorage.getItem("gympro.tangoAccess.url")

Debe devolver:

"http://127.0.0.1:8787/open"

Luego ejecutar:

localStorage.getItem("gympro.tangoAccess.token")

Debe devolver un valor que empieza con:

"gympro-"

7. PRUEBA FINAL EN GYMPRO

- Cerrar DevTools
- Ir a Home
- Click en Abrir visor
- Ingresar DNI en el visor
- Presionar Enter

Resultado esperado:

- Alumno autorizado: pantalla verde y molinete abre
- Alumno no autorizado: pantalla roja y molinete no abre

8. DESPUES DE APAGAR Y PRENDER LA PC

Si despues de reiniciar la PC el test muestra un error tipo:

No es posible conectar con el servidor remoto
No connection could be made
127.0.0.1:8787

El gateway local no esta corriendo.

Solucion inmediata:

- Abrir:

C:\GymProAccess\start-gateway.bat

- Dejar esa ventana abierta
- Ejecutar:

C:\GymProAccess\test-open.bat

Si asi abre el molinete, la integracion esta bien. Solo falta dejar configurado el inicio automatico con shell:startup.

9. DIAGNOSTICO RAPIDO

Si test-open.bat no abre:
El problema esta en C:\TangoAccess\abrir.exe o en la configuracion del proveedor del molinete.

Si test-open.bat abre, pero GymPro no abre:
Revisar CONFIGURAR-NAVEGADOR.txt y los 3 valores de localStorage.

Si test-open.bat muestra error de conexion a 127.0.0.1:8787:
El gateway no esta iniciado. Abrir C:\GymProAccess\start-gateway.bat y dejarlo abierto.

Si GymPro muestra acceso denegado:
Revisar el alumno, DNI, cuota o tenant dentro de GymPro.
