# Auditoría de Seguridad de Firestore

**Proyecto:** Barbería — Flutter Web + Firebase/Firestore
**Fecha:** 27 de septiembre de 2026
**Alcance:** análisis estático de código y de `firestore.rules`. Sin pruebas ofensivas, sin ejecución, sin cambios.
**Archivos modificados por esta auditoría:** ninguno. Este documento es el único archivo creado.

---

## 1. Estado actual

La aplicación opera con cinco colecciones: `usuarios`, `turnos`, `disponibilidad`, `servicios`, `barberos`.

El modelo de autorización tiene **una sola noción de privilegio**: el campo `rol` dentro de `usuarios/{uid}`, cuyo valor es `'admin'` o `'cliente'`. No existe el concepto de "administrador de una barbería concreta": un admin es global.

Existe un **espejo técnico** (`disponibilidad`) que permite a la agenda pública consultar horarios ocupados sin abrir `turnos`, que contiene datos personales.

**Veredicto general:** las escrituras sobre catálogos (`servicios`, `barberos`) sí están correctamente protegidas por rol. Sin embargo, **la colección `usuarios` permite escalada de privilegios trivial**, y `turnos` y `disponibilidad` tienen permisos de escritura y lectura demasiado amplios. Un cliente registrado común puede convertirse en administrador completo.

### 1.1 Limitaciones de esta auditoría

| No comprobado | Motivo |
|---|---|
Si las reglas **desplegadas** en el servidor coinciden con el `firestore.rules` local | No hay credenciales del proyecto en este entorno. Todo el análisis se basa en el archivo local. Si el archivo local no refleja lo desplegado, las conclusiones cambian |
| Si la base de datos tiene índices, usuarios o documentos inconsistentes | Sin acceso a los datos |
| Si existen reglas de App Check, funciones de Cloud o triggers no presentes en el repo | No hay código en el repositorio que los referencie |
| Comportamiento ante reglas actualmente desplegadas que difieran del archivo | Requiere `firebase deploy --only firestore:rules --dry-run` o revisar la consola |

---

## 2. Reglas actuales encontradas

Archivo `firestore.rules` (45 líneas, `rules_version = '2'`), reproducido textualmente:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /barberos/{barberId} {              // línea 5
      allow read: if true;                    // línea 6
      allow write: if request.auth != null &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin';
    }

    match /servicios/{serviceId} {            // línea 13
      allow read: if true;                    // línea 14
      allow write: if request.auth != null &&
        exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin';
    }

    match /usuarios/{userId} {                // línea 21
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /turnos/{turnoId} {                 // línea 26
      allow read: if request.auth != null;     // línea 27
      allow create: if request.auth != null;   // línea 28
      allow update, delete: if request.auth != null && (
        request.auth.uid == resource.data.userId ||
        (exists(/databases/$(database)/documents/usuarios/$(request.auth.uid)) &&
         get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin')
      );
    }

    match /disponibilidad/{slotId} {          // línea 40
      allow read: if true;                    // línea 41
      allow write: if request.auth != null;   // línea 42
    }
  }
}
```

### 2.1 Observaciones sobre la forma de las reglas

- **No hay regla comodín** (`match /{document=**}`). Con `rules_version = '2'`, todo acceso a una ruta no declarada queda **denegado por defecto**. Es una buena base: cualquier colección futura queda cerrada por defecto.
- La condición de admin es un patrón repetido literalmente en tres sitios. No hay función compartida ni `isAdmin()` reutilizable: cada cambio future debe editar las tres copias.
- `read` y `write` se evalúan **por documento**. En consultas (`list`), la regla debe cumplirse para todos los documentos potencialmente devueltos.

---

## 3. Operaciones por colección

| Colección | read | create | update | delete |
|---|---|---|---|---|
`usuarios` | Solo el propio (`uid == userId`) | Solo el propio (implícito en `write`) | Solo el propio | Solo el propio (implícito) |
`turnos` | **Cualquier autenticado** | **Cualquier autenticado** | Dueño del turno **o** admin | Dueño del turno **o** admin |
`disponibilidad` | **Público (anónimos incluidos)** | **Cualquier autenticado** | **Cualquier autenticado** | **Cualquier autenticado** |
`servicios` | Público | Admin | Admin | Admin |
`barberos` | Público | Admin | Admin | Admin |

### 3.1 Campos de `turnos` y quién los controla

`Appointment.toMap()` (`lib/models/appointment.dart:34-50`) más dos campos añadidos en `FirestoreService.saveAppointment()` (`:109-113`):

| Campo | Tipo | Origen en la app | Validado por reglas |
|---|---|---|---|
`userId` | String | `authProvider.uid` (`booking_form.dart:226`) | ❌ **No** |
`customerName` | String | `authProvider.nombreCompleto` / `email` | ❌ No |
`customerEmail` | String | `authProvider.email` | ❌ No |
`barberId` | String | `_selectedBarber!.id` | ❌ No |
`barberName` | String | `_selectedBarber!.name` | ❌ No |
`barberPhone` | String | `_selectedBarber!.phone` | ❌ No |
`serviceId` | String | `_selectedService!.id` | ❌ No |
`serviceName` | String | `_selectedService!.name` | ❌ No |
`servicePrice` | double | `_selectedService!.price` | ❌ **No** |
`date` | String | `"27 de Septiembre de 2026"` | ❌ No |
`time` | String | `"18:00 - 18:30"` | ❌ No |
`startTime` | String | derivado de `time` | ❌ No |
`status` | String | `AppointmentStatus.pending` (default) | ❌ **No** |
`appointmentDateTime` | Timestamp | `getParsedDateTime()` | ❌ No |
`timestamp` | serverTimestamp | servidor | ❌ No |

**Ningún campo de `turnos` está validado por las reglas.** El cliente es la única fuente de todos ellos.

Campos de `disponibilidad` (`firestore_service.dart:119-124`): `barberId`, `date`, `startTime`, `status`. **Tampoco validados**, y además se permite escribir campos arbitrarios adicionales.

Campos de `usuarios` en el registro (`auth_service.dart:34-41`): `uid`, `nombre`, `apellido`, `email`, `rol`, `fechaRegistro`. El `rol` lo fija el cliente y **las reglas no lo restringen**.

---

## 4. Flujo real de reserva

1. `booking_form.dart:195` — si el usuario **no está autenticado**, se abre `LoginModal`. **La reserva exige autenticación.** Esto es relevante: confirma que `allow create: if request.auth != null` es una condición necesaria y legítima.
2. `booking_form.dart:226` — `userId: authProvider.uid`, es decir el uid real de Firebase Auth. `auth_provider.dart:17` devuelve `_user?.uid ?? ''`.
3. `BookingProvider.confirmBooking()` → `BookingService.confirmBooking()` → `FirestoreService.saveAppointment()`.
4. `firestore_service.dart:81-125` — transacción única:
   - `slotId = _buildSlotId(barberId, date, startTime)` (ID determinista, `:71-79`)
   - `transaction.get(docRef)` → si existe, lanza `already-booked`
   - `transaction.set(turnos/{slotId}, {...})`
   - `transaction.set(disponibilidad/{slotId}, {barberId, date, startTime, status})`
5. Tras la escritura, `BookingService` envía el mensaje de WhatsApp (`booking_service.dart:51`).

**La protección contra doble reserva es lógica de cliente**, contenida dentro de la transacción. Las reglas de Firestore **no replican** esa verificación: replicate el `slotId` no es una restricción que las reglas impongan.

**Consecuencia de seguridad:** un cliente que no use el SDK de la app, sino la API REST o el SDK de Firestore directamente, puede escribir en `turnos/{docId}` **sin** la transacción y **sin** el chequeo `already-booked`.

### 4.1 Quién necesita qué operación

| Operación | Cliente | Admin |
|---|---|---|
Crear turno (reservar) | ✅ Necesario | ✅ |
Leer **sus propios** turnos | ✅ Necesario (no hay pantalla implementada hoy) | ✅ |
Leer **todos** los turnos | ❌ No debería | ✅ Necesario (Agenda + Turnos) |
Actualizar estado a `confirmed` / `completed` | ❌ No debería | ✅ Necesario |
Cancelar su propio turno | ✅ Necesario | ✅ |
Editar barbero/fecha/hora/servicio | ❌ No debería | ✅ Necesario (diálogo de edición) |
Eliminar turno | ❌ No debería | ✅ Necesario |
CRUD `servicios` | ❌ | ✅ Necesario |
CRUD `barberos` | ❌ | ✅ Necesario |
CRUD `usuarios` ajenos | ❌ | ✅ Necesario (hoy nadie puede) |

---

## 5. Permisos actuales de cliente (rol `'cliente'`)

**Puede:**
- Leer `usuarios/{su propio uid}` y escribirlo — **incluyendo `rol`**
- Reservar: crear `turnos` con **cualquier valor en cualquier campo**
- Leer **todos** los `turnos` de la base, con datos personales de terceros
- Actualizar y eliminar **sus propios** turnos, con cualquier campo
- Crear, actualizar y borrar **cualquier** documento de `disponibilidad`
- Leer `servicios` y `barberos` (público, previsto)

**No puede:**
- Crear, leer, modificar o borrar `servicios`
- Crear, leer, modificar o borrar `barberos`
- Actualizar o eliminar turnos de **otros** usuarios
- Leer o escribir `usuarios` de **otros** usuarios

## 6. Permisos actuales de administrador (rol `'admin'`)

**Puede:** todo lo anterior, más CRUD completo de `servicios` y `barberos`, además de leer y modificar **cualquier** turno. Con una única excepción: no puede administrar `usuarios` ajenos, porque esa capacidad no existe en las reglas.

`usuarios` **no tiene** ninguna rama que conceda acceso a administradores. La línea 22 es `allow read, write: if request.auth != null && request.auth.uid == userId`. Por lo tanto **un administrador no puede leer ni escribir el documento de ningún otro usuario, ni el suyo propio de forma privilegiada**. Cualquier función futura de administración de usuarios requeriría modificar las reglas.

Además, `FirestoreService` define un método para listar todos los usuarios (`firestore_service.dart:223`, `_db.collection('usuarios').get()`), pero **no se usa en ninguna parte del código**. Bajo las reglas actuales, esa consulta fallaría siempre. Es código muerto.

**No puede:** nada relevante.

### 6.1 Distinción entre Ezequiel (B1) e Isaías (B2)

Las reglas **no distinguen** entre los dos administradores. `rol == 'admin'` es un privilegio **global y sin ámbito de barbería**:

- Un admin puede leer, editar y cancelar turnos de **cualquier** barbero.
- Un admin puede modificar el documento de `barberos/B1` o `barberos/B2` indistintamente.
- `usuarios` no tiene campo `barberId`: no existe el concepto de "admin de su barbería".

Ambos administers son intercambiables y equivalentes a un superusuario del sistema.

### 6.2 Interfaz versus seguridad

Esta distinción es central en este proyecto, y el resultado es desfavorable.

`AdminProvider` **no contiene ninguna verificación de rol** (verificado: no hay coincidencias de `isAdmin` ni `rol` en el archivo). Es un simple pasamanos hacia `FirestoreService`. Lo mismo ocurre con `BookingService`.

La única barrera de rol en el cliente es `admin_panel.dart:45`:

```
if (!authProvider.isAdmin) { ...Navigator.pop... }
```

y `custom_app_bar.dart:72`, que **oculta** el enlace al panel.

**Conclusión:** la UI es una comprobación de cortesía, no un control de seguridad. Para operar sobre `turnos`, `servicios` o `barberos` fuera de la app, un atacante no necesita tocar Flutter: le basta emitir las llamadas directamente contra la API de Firestore con su token. Lo único que se interpone son las reglas.

A favor del proyecto: en `servicios` y `barberos` **las reglas repiten el requisito de rol**, de modo que la comprobación del cliente está respaldada por una del servidor. En `turnos` la comprobación existe solo para `update`/`delete`, y no para `read` ni `create`.

---

## 7. Riesgos encontrados

### CRÍTICO — C1. Escalada de privilegios vía `usuarios.rol`

**Regla culpable:** `firestore.rules:22`
```
allow read, write: if request.auth != null && request.auth.uid == userId;
```

`auth_service.dart:34-41` escribe `rol: 'cliente'` desde el cliente, pero **eso es una cortesía de la app, no una garantía**. Las reglas no comprueban el valor de `rol` en ningún momento.

Un usuario autenticado cualquiera puede emitir, desde la consola del navegador o cualquier cliente REST:

```
setDoc(doc(db, 'usuarios', miUid), { uid: miUid, email: '...', rol: 'admin' })
```

La regla se cumple: el `uid` de la ruta coincide con el del solicitante. El documento se reescribe por completo (`set` sin merge).

**Impacto:** el atacante pasa a ser admin. Consecuencia encadenada:
- puede escribir `servicios` y `barberos` (las reglas solo exigen `rol == 'admin'`)
- puede actualizar y eliminar cualquier `turnos`
- puede leer y escribir `usuarios` de terceros… salvo que esto último sigue bloqueado por el `uid == userId`. Esa limitación **no reduce el impacto**, porque el atacante ya dispone de control total sobre los catálogos y los turnos.

**Agravante:** el registro público (`register_screen.dart`, `auth_service.dart`) permite a cualquiera obtener una cuenta válida sin fricción, así que el prerrequisito es trivial.

**Este hallazgo encadena con todos los demás:** las comprobaciones de admin en `servicios`, `barberos` y `turnos` son tan fuertes como la integridad de `usuarios.rol`, que es controlable por el atacante.

### CRÍTICO — C2. Fuga masiva de datos personales

**Regla culpable:** `firestore.rules:27`
```
allow read: if request.auth != null;
```

Cualquier usuario autenticado —incluido el más anodino, recién registrado— puede leer la colección `turnos` **completa**, que contiene `customerName`, `customerEmail`, `barberPhone` y `userId` de todos los clientes de la barbería.

Las consultas usadas por la aplicación (`getAppointmentsStream()` con filtro por fecha, `getAppointmentsCountByStatus()`, `checkExistingBooking()`) también son alcanzables por cualquier cliente autenticado, porque la regla no las distingue.

**Contraste con la colección `usuarios`:** el documento personal sí está correctamente restringido a su dueño. Hay una inconsistencia de criterio entre `usuarios` (restringido) y `turnos` (abierto a todos los autenticados).

El diseño ya demuestra que la Collection Group Query no era necesaria: `disponibilidad` existe precisamente para exponer horarios **sin** exponer datos personales. El mismo razonamiento se aplicaría a `turnos`.

### CRÍTICO — C3. Creación de turnos sin validación de campos

**Regla culpable:** `firestore.rules:28`
```
allow create: if request.auth != null;
```

No valida ningún campo. Un cliente autenticado puede crear un documento con:

| Abuso | Payload | Efecto |
|---|---|---|
Suplantar identidad | `userId: '<uid de otra persona>'` | El turno queda a nombre de un tercero. Como las reglas de update/delete comprueban `resource.data.userId`, **el atacante pierde acceso y el tercero queda como dueño** de un turno que él no solicitó |
Falsificar estado | `status: 'confirmed'` | Salta el flujo administrativo: un turno auto-aprobado sin intervención de la barbería |
Manipular precio | `servicePrice: 0` | El precio queda registrado como 0 en el documento de referencia |
Precio arbitrario | `servicePrice: 99999` | Precios desincronizados del catálogo |
Forjar contacto | `customerEmail: 'victima@ejemplo.com'` | Datos de contacto falsos en un turno real |
Denegación de servicio | `create` en `turnos/B1_<fecha>_18:00` para todos los horarios | **Bloquea la agenda real**: el `slotId` es determinista y adivinable, y la transacción de la app rechazará los intentos legítimos con `already-booked` |
Horario fuera de catálogo | `startTime: '03:00'` | Turnos a horarios no ofrecidos |

**Matiz importante:** la escritura directa por API no pasa por la transacción de `saveAppointment()`. Por eso el `already-booked` no protege contra esto, y el atacante **sí** puede ocupar un `slotId` que la app considera libre. La doble reserva sigue siendo imposible, pero se vuelve trivial bloquear la disponibilidad.

**Matiz sobre los datos personales:** un turno creado bajo el `uid` del atacante no constituye un acceso a datos de terceros, sino un registro insertado en su propio nombre. El riesgo real es la inyección de disponibilidad y la falsificación de estado, no la copia de datos ajenos.

### ALTO — A1. Manipulación de `disponibilidad` por cualquier cliente

**Regla culpable:** `firestore.rules:42`
```
allow write: if request.auth != null;
```

`disponibilidad` es la colección que la agenda pública consulta para saber qué horarios están ocupados (`firestore_service.dart:160-171`). Cualquier cliente autenticado puede escribir en ella.

| Abuso | Efecto |
|---|---|
`set` con `status: 'cancelled'` sobre un slot ocupado | **El horario aparece LIBRE** al resto de los clientes |
`delete` de un documento de disponibilidad | **El horario aparece LIBRE** |
`create` de un documento con un `slotId` válido | **El horario aparece OCUPADO** sin reserva real |
Campos arbitrarios | Se pueden inyectar campos no previstos; ninguna regla lo impide |

**Alcance real del daño — importante para la priorización:** la manipulación de `disponibilidad` **no produce doble reserva**. La autoridad final es la transacción sobre `turnos`, que sigue intacta. El daño es de **integridad de la vista pública**:

- Un atacante puede provocar que un cliente real intente reservar un slot ya ocupado y reciba el error "el turno acaba de ser reservado por alguien más", que es confuso pero seguro.
- Puede dejar la agenda pública permanentemente desincronizada del estado real.

Es un ataque de denegación de servicio y de suplantación del estado de un horario, no de corrupción de los datos de reserva.

### ALTO — A2. El dueño de un turno puede alterar campos que no le pertenecen

**Regla culpable:** `firestore.rules:29-33`. La condición `request.auth.uid == resource.data.userId` permite al dueño modificar **cualquier** campo de su propio turno.

El cliente puede, sobre su propio turno:
- `servicePrice: 0` — alterar el precio registrado
- `serviceName: 'Corte gratis'` — alterar la descripción
- `status: 'confirmed'` — auto-aprobar su turno y saltar la confirmación de la barbería
- `date` / `time` / `barberId` — mover su turno a otro horario, **sin pasar por la verificación de disponibilidad** que la app sí realiza en el diálogo de edición (`appointments_tab.dart:655-673`)
- `userId: '<otro uid>'` — transferir la propiedad del documento; **el atacante pierde el acceso y el nuevo dueño lo adquiere**, y ya puede modificarlo o eliminarlo

**No puede** tocar turnos de terceros. Esa parte está bien resuelta.

### MEDIO — M1. Regla de update/delete dependiente de un campo que el cliente controla

`resource.data.userId` se usa como criterio de propiedad. Dado que C3 permite crear turnos con un `userId` arbitrario, la "propiedad" de un turno no significa nada confiable.

Caso límite: si `userId` es `''` —lo que `auth_provider.dart:17` devuelve cuando no hay sesión, aunque en el flujo normal la reserva exige login— la comparación `request.auth.uid == ''` nunca se cumple y **solo un admin podría modificar o eliminar ese turno**. Riesgo de turnos huérfanos irrecuperables para el cliente.

### MEDIO — M2. El panel de administración no implementa usuarios

`FirestoreService` expone `getAllUsers()` (`:223`) y no lo usa. La colección `usuarios` no tiene rama de admin. No es una vulnerabilidad, pero indica una funcionalidad de gestión de usuarios inconclusa: **hoy no existe forma de promover a un usuario a admin dentro de la app**.

### BAJO — B1. Ausencia de reglas para escalares y validación de claves

No hay reglas que restrinjan `keys().hasOnly(...)`. Un cliente puede escribir campos arbitrarios en `usuarios`, `turnos` y `disponibilidad`, y leerlos. No es una vía de escalada por sí mismo, pero ensancha el modelo de datos y complica auditoría y migraciones futuras.

### BAJO — B2. Condición de admin triplicada

El patrón `exists(...) && get(...).data.rol == 'admin'` está copiado en tres lugares. Cualquier endurecimiento del criterio de admin exige editar las tres copias; olvidar una deja una vía abierta. Una función `isAdmin()` sería más segura.

---

## 8. Casos permitidos / denegados

Analízado conceptualmente sobre el código real, sin ejecutar ataques.

| # | Acción | Estado | Regla o código que lo determina |
|---|---|---|---|
1 | Anónimo lee `servicios` | **PERMITIDO** | `firestore.rules:14` `allow read: if true` |
2 | Anónimo lee `barberos` | **PERMITIDO** | `firestore.rules:6` `allow read: if true` |
3 | Anónimo lee `disponibilidad` | **PERMITIDO** | `firestore.rules:41` `allow read: if true` — previsto por diseño |
4 | Anónimo lee `turnos` | **DENEGADO** | `firestore.rules:27` requiere `request.auth != null` |
5 | Anónimo escribe en cualquier colección | **DENEGADO** | Todas las escrituras exigen `request.auth != null` |
6 | Cliente lee sus propios datos de `usuarios` | **PERMITIDO** | `firestore.rules:22` |
7 | Cliente escribe su propio documento de `usuarios` con `rol: 'admin'` | **PERMITIDO** | `firestore.rules:22` — no valida `rol`. **C1** |
8 | Cliente lee `usuarios` de otro | **DENEGADO** | `firestore.rules:22` `request.auth.uid == userId` |
9 | Cliente escribe `usuarios` de otro | **DENEGADO** | `firestore.rules:22` |
10 | Admin lee `usuarios` de otro | **DENEGADO** | `firestore.rules:22` — no hay rama de admin. **M2** |
11 | Cliente reserva un horario libre | **PERMITIDO** | `firestore.rules:28`; flujo legitimate en `booking_form.dart:195-232` |
12 | Cliente reserva un horario ya ocupado | **DENEGADO** | No por las reglas, sino por la transacción en `firestore_service.dart:100-106` |
13 | Cliente lee turnos de otros clientes | **PERMITIDO** | `firestore.rules:27` `allow read: if request.auth != null`. **C2** |
14 | Cliente crea un turno con `userId` de otro | **PERMITIDO** | `firestore.rules:28` no valida `userId`. **C3** |
15 | Cliente crea un turno con `status: 'confirmed'` | **PERMITIDO** | `firestore.rules:28` no valida `status`. **C3** |
16 | Cliente crea un turno con `servicePrice: 0` | **PERMITIDO** | `firestore.rules:28` no valida `servicePrice`. **C3** |
17 | Cliente bloquea la agenda creando `turnos` en todos los slots | **PERMITIDO** | `firestore.rules:28` + `slotId` determinista y adivinable. **C3** |
18 | Cliente **modifica** un turno ajeno | **DENEGADO** | `firestore.rules:29-30` `request.auth.uid == resource.data.userId` falla; rama de admin también |
19 | Cliente **cancela** un turno ajeno | **DENEGADO** | Misma regla que #18 |
20 | Cliente **elimina** un turno ajeno | **DENEGADO** | Misma regla que #18 |
21 | Cliente cambia `servicePrice` en su propio turno | **PERMITIDO** | `firestore.rules:29-30` no restringe campos en update. **A2** |
22 | Cliente auto-aprueba su turno (`status: 'confirmed'`) | **PERMITIDO** | `firestore.rules:29-30`. **A2** |
23 | Cliente mueve su turno a un horario ya ocupado | **PERMITIDO** | El `update` no comprueba disponibilidad. **A2** |
24 | Cliente transfiere su turno a otro `userId` | **PERMITIDO** | `firestore.rules:29-30` no restringe `userId` en update. **A2** |
25 | Cliente escribe `disponibilidad` para bloquear un horario | **PERMITIDO** | `firestore.rules:42`. **A1** |
26 | Cliente marca un slot ocupado como `cancelled` | **PERMITIDO** | `firestore.rules:42`. **A1** |
27 | Cliente borra un documento de `disponibilidad` | **PERMITIDO** | `firestore.rules:42`. **A1** |
28 | Cliente logra una doble reserva real | **DENEGADO** | Transacción en `firestore_service.dart:96-125` + `slotId` determinista |
29 | Cliente modifica `servicios` | **DENEGADO** | `firestore.rules:15-17` exige `rol == 'admin'` — **siempre que no haya escalado por C1** |
30 | Cliente elimina `barberos` | **DENEGADO** | `firestore.rules:7-9` — mismo matiz de C1 |
31 | Cliente que se auto-asignó `rol: 'admin'` modifica `servicios` | **PERMITIDO** | Consecuencia encadenada de C1 |
32 | Ezequiel lee turnos de Isaías | **PERMITIDO** | Sin ámbito de barbería en las reglas. §6.1 |
33 | Ezequiel edita un turno de Isaías | **PERMITIDO** | Rama de admin de `firestore.rules:31-32` |
34 | Cliente altera su `servicePrice` **dentro de `servicios`** | **DENEGADO** | `firestore.rules:15-17` |
35 | Cliente altera la duración de un servicio | **DENEGADO** | Misma regla que #34 |
36 | Cliente crea campos arbitrarios en `disponibilidad` | **PERMITIDO** | `firestore.rules:42` no valida `keys()`. **B1** |
37 | Cliente accede a una colección no declarada | **DENEGADO** | Sin regla comodín + `rules_version = '2'` |

### 8.1 Nota sobre la duración

El campo de duración de un servicio vive en `servicios`, no en `turnos`. `firestore_service.dart:368-400` expone `addService`/`updateService`/`deleteService`; la escritura está correctamente protegida. **Riesgo residual:** si un admin cambia el precio o la duración de un servicio, los turnos ya registrados conservan el valor histórico (`servicePrice` se copia en el turno), lo cual es el comportamiento correcto para preservar el histórico. No es un riesgo.

---

## 9. Cambios recomendados para una segunda etapa

**Nada de lo siguiente está implementado. Se documenta con sus efectos.**

### 9.1 Cerrar la escalada de privilegios (prioridad máxima)

Dividir `usuarios` en reglas diferenciadas y blindar `rol`:

```
allow create: if request.auth != null && request.auth.uid == userId
              && request.resource.data.rol == 'cliente';
allow read:   if request.auth != null && request.auth.uid == userId;
allow update: if request.auth != null && (
                (request.auth.uid == userId
                 && request.resource.data.rol == resource.data.rol)
                || isAdmin());
allow delete: if isAdmin();
```

**¿Rompe algo?** No. El registro (`auth_service.dart:34-41`) escribe exactamente `rol: 'cliente'` sobre su propio uid: la nueva regla de `create` se cumple. El login (`auth_service.dart:83-88`) solo lee: sigue funcionando. El admin conserva su capacidad de leer su propio documento.

**Salvedad:** una vez desplegado, promover a Ezequiel o Isaías a admin **no podrá hacerse desde la app**: habría que hacerlo con la consola de Firebase o con un script con credenciales de servicio. Conviene planificar ese procedimiento antes de aplicar el cambio.

### 9.2 Centralizar la condición de admin

Definir una función reutilizable en lugar de repetir el patrón tres veces:

```
function isAdmin() {
  return request.auth != null
    && exists(/databases/$(database)/documents/usuarios/$(request.auth.uid))
    && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin';
}
```

Elimina el riesgo de olvidar actualizar una copia. **No cambia comportamiento.**

### 9.3 Blindar la creación de turnos

```
allow create: if request.auth != null
              && request.resource.data.userId == request.auth.uid
              && request.resource.data.status == 'pending'
              && request.resource.data.keys().hasOnly([...]);
```

**¿Rompe algo?** No, si se despliega después de 9.1. La app ya envía `userId` real (`booking_form.dart:226`) y `status` es `pending` por defecto (`appointment.dart:31`).

**Lo que NO se debe validar en las reglas:** `servicePrice`. Exigir que coincida con `servicios/{serviceId}.price` obliga a una lectura extra por escritura, y falla si el servicio fue borrado o su precio cambió entre la lectura del formulario y la confirmación. La validación de precio pertenece a una Cloud Function o al proceso administrativo, no a las reglas.

**Para la denegación de servicio por slots (C3):** las reglas pueden exigir que el documento no existiera y que los campos sean coherentes, pero **no pueden verificar la agenda real** sin un índice de horarios en Firestore. Esta limitación solo se resuelve con una Cloud Function que valide contra la configuración real, o reservando los slots en el cliente con una sesión transaccional. Queda fuera del alcance de las reglas.

### 9.4 Restringir la lectura de `turnos`

```
allow get:  if isAdmin() || resource.data.userId == request.auth.uid;
allow list: if isAdmin();
```

**¿Rompe algo?** No hoy. Las únicas consultas a `turnos` del código son las del panel administrativo (`agenda_tab.dart:95`, `appointments_tab.dart:39`) y las de validación interna (`checkExistingBooking`), todas ejecutadas por admins. La agenda pública ya usa `disponibilidad`.

**Requisito previo a verificar:** `checkExistingBooking()` (`firestore_service.dart:177-182`) se invoca desde el flujo de reserva del cliente. Si su llamador es un cliente, la regla `list: if isAdmin()` **rompería la reserva**. Hay que determinar si esa función sigue siendo necesaria en el camino del cliente ahora que la transacción cubre el caso, y en su caso eliminarla del flujo o eximirla.

**Si en el futuro se agrega una pantalla "Mis turnos"**, la regla debe permitir consultas filtradas por `userId`, lo que en Firestore exige que la consulta incluya `.where('userId', '==', auth.uid)` y un índice por ese campo. Es un cambio de código además de reglas.

### 9.5 Endurecer `disponibilidad`

La clave: **distinguir creación de modificación**, porque el cliente solo crea y el admin solo modifica o borra.

```
match /disponibilidad/{slotId} {
  allow read: if true;
  allow create: if request.auth != null
                && request.resource.data.keys().hasOnly(
                     ['barberId', 'date', 'startTime', 'status']);
  allow update, delete: if isAdmin();
}
```

**¿Rompe algo?** No, según el código revisado:
- `create` lo usa exclusivamente `saveAppointment()` (`:119`), en el flujo de reserva del cliente
- `update` aparece en `updateAppointmentStatus()` (`:264`) y `_syncAvailabilityAfterEdit()` (`:312`, `:335`), ambos alcanzables solo desde `appointments_tab.dart` (admin)
- `delete` aparece en `deleteAppointment()` (`:281`) y `_syncAvailabilityAfterEdit()` (`:333`), igualmente solo desde admin

**Salvedad relevante:** al crear la regla de `create` conviene confirmar que en la evaluación de la transacción de `saveAppointment()` las reglas ven ya el `turnos/{slotId}` creado. Si se quisiera exigir además `exists(/.../turnos/$(slotId))`, **esa hipótesis debe probarse en el emulador antes de desplegar**, porque la semántica de evaluación de reglas dentro de una transacción con múltiples escrituras no debe asumirse. La opción `hasOnly` es segura y no depende de esa semántica.

**Pendiente de una etapa posterior:** la restauración de mirrors de `disponibilidad` para los turnos anteriores a la colección (backfill), que hoy quedan sin reflejo utilizable.

### 9.6 Restricción de campos en catálogos

Aplicar `keys().hasOnly([...])` en `servicios` y `barberos` para `create` y `update`, y exigir que los campos de precio y duración sean del tipo correcto. Endurece el modelo sin cambiar el comportamiento del CRUD administrativo.

### 9.7 Resumen de prioridades

| Prioridad | Acción | Rompe funcionalidad existente |
|---|---|---|
P0 | 9.1 Blindar `usuarios.rol` | No, pero exige definir el procedimiento de promoción a admin |
P0 | 9.5 Separar `create` de `update/delete` en `disponibilidad` | No |
P1 | 9.3 Blindar `create` de `turnos` | No, si se aplica tras 9.1 |
P1 | 9.4 Restringir `read` de `turnos` | **Posible**: verificar `checkExistingBooking` |
P2 | 9.2 Función `isAdmin()` | No |
P2 | 9.6 `hasOnly` en catálogos | No |
P3 | Cloud Function para precios y slots | No, pero es trabajo mayor |

**El orden importa:** 9.1 debe preceder a 9.3, porque hasta que `rol` sea inalterable por el usuario, endurecer `turnos` no impide que un cliente se convierta en admin y administre todos los turnos.

---

## 10. Archivos que habría que modificar posteriormente

### 10.1 Para endurecer las reglas (sin tocar código Dart)

| Archivo | Cambio |
|---|---|
`firestore.rules` | Único archivo necesario para 9.1, 9.2, 9.3, 9.4, 9.5 y 9.6 |
`firestore.indexes.json` | Posible índice nuevo en `turnos` por `userId` si se habilita "Mis turnos" |

Esta es la buena noticia del proyecto: **los hallazgos críticos se corrigen íntegramente en un solo archivo**, sin una sola línea de Dart.

### 10.2 Solo si se implementa "Mis turnos" para clientes

| Archivo | Cambio |
|---|---|
`lib/services/firestore_service.dart` | Nueva consulta con `.where('userId', '==', uid)` |
`lib/providers/booking_provider.dart` | Exponer el stream al cliente |
`lib/widgets/` | Nueva pantalla — **funcionalidad nueva, fuera del alcance actual** |

### 10.3 Procedimiento operativo, no código

Promoción de usuarios a `rol: 'admin'` mediante consola de Firebase o script con cuenta de servicio, una vez que 9.1 impida hacerlo desde la app.

---

## 11. Funcionalidades que podrían romperse si se modifican las reglas incorrectamente

| Regla propuesta | Qué podría romperse | Cómo evitarlo |
|---|---|---|
`usuarios.rol` inmutable para el propietario | La promoción a admin desde la app deja de funcionar | Planificar el procedimiento por consola **antes** de desplegar |
`turnos.create` exige `status == 'pending'` | Nada en el flujo actual | Ninguna; el default ya es `pending` |
`turnos.create` con `keys().hasOnly([...])` | Rompe si se agregan campos al modelo en el futuro | Mantener la lista sincronizada con `Appointment.toMap()` |
`turnos.list` restringida a admin | **La reserva**, si `checkExistingBooking()` se ejecuta en el camino del cliente | Verificar el llamador de `firestore_service.dart:177` y `:348` antes de aplicar |
`turnos.create` validando `servicePrice` contra `servicios` | La reserva se rompe si el servicio se borró o cambió de precio entre leer y confirmar | **No validar precio en reglas**; dejarlo a una Cloud Function |
`disponibilidad.update/delete` solo admin | Nada hoy | Confirmar que ningún camino del cliente escribe o borra el espejo |
`usuarios.delete` solo admin | Nada | No existe eliminación de usuarios en la app |
Añadir una regla comodín `match /{document=**}` sin revisar | Puede abrir por error colecciones hoy cerradas | `rules_version = '2'` ya deniega por defecto; un comodín explícito es un retroceso |

**Advertencia general:** las reglas se despliegan de forma atómica pero afectan a **todos los clientes conectados simultáneamente**, incluida la app ya abierta en los móviles de los clientes. Conviene hacer pruebas con el emulador de Firestore antes de desplegar en producción.

---

## 12. Conclusión técnica

El sistema parte de una decisión de diseño correcta — `disponibilidad` como espejo sin datos personales, y una Collection Group Query que no expone `turnos` al público — pero **las reglas no terminan de acompañar ese diseño**.

La asimetría es el patrón dominante: `servicios` y `barberos` exigen rol de admin en cada escritura, mientras que `usuarios`, `turnos` y `disponibilidad` confiaron en que el código de la app se portaría bien. En un cliente Flutter Web, el código de la app está íntegramente en manos del usuario, y puede ser inspeccionado, emulado o reemplazado. La única frontera de confianza real son las reglas.

El hallazgo que agrava a todos los demás es **C1**: la condición que decide quién es administrador se apoya en un campo (`usuarios.rol`) que el propio usuario puede reescribir. Mientras siga así, los controles de admin sobre `servicios`, `barberos` y `turnos` son decorativos: basta con una llamada para convertirlos en inútiles. Cualquier endurecimiento aplicado sin resolver primero C1 produce una falsa sensación de seguridad.

El segundo hallazgo, **C2**, es una filtración de datos personales de clientes a cualquier persona que abra una cuenta —operación que la app permite de forma abierta. La colección `disponibilidad` ya demuestra que el proyecto sabe evitar esta exposición en la agenda pública; el mismo criterio debería aplicarse a `turnos`.

En el lado positivo, hay dos aciertos de arquitectura que conviene preservar: la **transacción atómica** que escribe `turnos` y `disponibilidad` juntas, con `slotId` determinista, que garantiza la integridad de la reserva incluso frente a un cliente malicioso; y la **ausencia de regla comodín**, que mantiene cerradas por defecto cualquier colección no prevista.

La corrección de los hallazgos críticos **no requiere escribir una sola línea de Dart**: se concentra en `firestore.rules`, con un orden de aplicación que empieza por cerrar la escalada de privilegios. Los riesgos que quedan fuera del alcance de las reglas —el precio y el bloqueo masivo de agenda— requieren una Cloud Function, y conviene tratarlos como un proyecto aparte.

**Prioridad de trabajo: 9.1 → 9.5 → 9.3 → 9.4, con 9.2 aplicado de entrada.**

---

*Auditoría de solo lectura. No se modificó ningún archivo del proyecto. Este documento es el único artefacto creado.*
