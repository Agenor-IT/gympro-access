# GymPro Access

Conector local para abrir molinetes TangoAccess desde GymPro.

El instalador configura un gateway local en la PC del gimnasio:

```text
http://127.0.0.1:8787/open
```

Cuando GymPro autoriza un ingreso, llama a ese gateway. El gateway ejecuta:

```text
C:\TangoAccess\abrir.exe
```

## Instalacion en la PC del gym

1. Confirmar que el proveedor del molinete instalo:

```text
C:\TangoAccess\abrir.exe
```

2. Descargar `GymProAccessInstaller.zip` desde Releases o con este comando:

```powershell
Invoke-WebRequest -Uri "https://github.com/Agenor-IT/gympro-access/releases/latest/download/GymProAccessInstaller.zip" -OutFile "$env:USERPROFILE\Downloads\GymProAccessInstaller.zip"
```

3. Descomprimir el ZIP.

4. Ejecutar:

```text
install.bat
```

5. Aceptar los valores por defecto, salvo que el proveedor haya cambiado la ruta de `abrir.exe`.

6. Abrir:

```text
C:\GymProAccess\CONFIGURAR-NAVEGADOR.txt
```

7. Copiar las lineas indicadas en la consola de Chrome con GymPro abierto.

## Pruebas

Estado del gateway:

```text
C:\GymProAccess\test-health.bat
```

Apertura del molinete:

```text
C:\GymProAccess\test-open.bat
```

Si `test-open.bat` abre el molinete, la integracion fisica esta funcionando.

## Operacion diaria

1. Abrir GymPro.
2. Ir a Home.
3. Click en `Abrir visor`.
4. Mover esa ventana al monitor del alumno.
5. El alumno ingresa DNI.
6. Si GymPro autoriza, el molinete abre.
