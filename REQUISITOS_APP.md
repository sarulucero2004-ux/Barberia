# Documento de Requisitos — Sistema Web de Barbería

## 1. Información general del proyecto

**Nombre del proyecto:** Golden Scissors | Barbería Premium
**Tipo:** Aplicación web para una barbería masculina.
**Tecnologías:** Flutter Web + Firebase.

**Objetivo principal:** Permitir que los clientes conozcan la barbería, consulten los servicios disponibles y puedan reservar turnos seleccionando un barbero, fecha y horario.

**Objetivos secundarios**
- Facilitar la gestión de turnos.
- Permitir administrar barberos.
- Permitir administrar servicios y precios.
- Mostrar disponibilidad actualizada.
- Permitir a los clientes consultar sus turnos.
- Reducir la gestión manual de reservas.
- Centralizar la información de la barbería.

---

## 2. Tipos de usuarios

El sistema tendrá principalmente dos tipos de usuarios.

### Cliente

Puede:
- Ver la página principal.
- Ver información de la barbería.
- Ver servicios y precios.
- Ver los barberos.
- Consultar disponibilidad.
- Seleccionar un barbero.
- Seleccionar fecha y horario.
- Reservar un turno.
- Consultar sus propios turnos.
- Cancelar un turno, si esta función está habilitada.

### Administrador

Puede:
- Iniciar sesión.
- Ver los turnos.
- Gestionar la agenda.
- Gestionar horarios disponibles.
- Gestionar servicios.
- Gestionar precios.
- Gestionar barberos.
- Modificar información visible en la página.
- Cancelar o modificar turnos.
- Consultar información general del sistema.

---

## 3. Página principal

La página principal será la parte pública de la aplicación.

### Secciones

#### Header / AppBar

Debe contener:
- Logo/nombre de la barbería.
- Inicio.
- Servicios.
- Barberos.
- Galería.
- Reservar turno.
- Iniciar sesión.

El acceso de administrador debe estar en el AppBar, no perdido en el pie de página.

#### Hero

Debe presentar:
- Nombre de la barbería.
- Frase representativa.
- Imagen principal.
- Botón "Reservar turno".

#### Sobre nosotros

Información breve sobre:
- La barbería.
- Experiencia.
- Estilo de trabajo.
- Propuesta del negocio.

#### Servicios

Mostrar los servicios disponibles.

| Servicio | Descripción | Precio |
|----------|-------------|--------|
| Corte clásico | Corte tradicional | $X |
| Fade | Degradado | $X |
| Barba | Perfilado y arreglo | $X |

**Importante:** los servicios deben obtenerse desde Firebase para que el administrador pueda modificarlos.

#### Barberos

Actualmente habrá 2 barberos. Cada tarjeta debería mostrar:
- Nombre.
- Especialidades.
- Información breve.
- Imagen, si se decide utilizar imágenes.

El cliente deberá poder elegir cuál de los dos barberos quiere al reservar.

#### Galería

Mostrar imágenes relacionadas con:
- Cortes.
- Barbería.
- Instalaciones.
- Trabajos realizados.

#### Contacto

Mostrar:
- Ubicación.
- Horarios de atención.
- Medio de contacto.
- Redes sociales, si corresponde.

---

## 4. Sistema de reservas

Esta es una de las partes principales del proyecto.

### Flujo del cliente

Página principal
        ↓
Reservar turno
        ↓
Elegir barbero
        ↓
Elegir fecha
        ↓
Ver horarios disponibles
        ↓
Elegir horario
        ↓
Ingresar datos
        ↓
Confirmar turno
        ↓
Turno registrado

### Paso 1 — Selección del barbero

El cliente debe elegir uno de los dos barberos.

Por ejemplo:

> ¿Con quién querés reservar?
>
> [ Ezequiel ]     [ Isaías ]

Una vez seleccionado, la disponibilidad debe corresponder a ese barbero.

---

## 5. Calendario y disponibilidad

La disponibilidad debe estar relacionada con:

Barbero + Fecha + Horario


Por ejemplo:

**Ezequiel — 15/09/2026**

| Hora | Estado |
|------|--------|
| 10:00 | Disponible |
| 10:30 | Ocupado |
| 11:00 | Disponible |
| 11:30 | Disponible |

**Isaías — 15/09/2026**

| Hora | Estado |
|------|--------|
| 10:00 | Ocupado |
| 10:30 | Disponible |
| 11:00 | Disponible |
| 11:30 | Ocupado |

### Firebase

La información de agenda debe poder administrarse desde Firebase. Una estructura posible sería:

barberos ├── b1 │ ├── nombre │ └── ... │ └── b2 ├── nombre └── ...

horarios ├── ...

turnos ├── ...


Los turnos reservados deben almacenarse en Firestore y utilizarse para determinar qué horarios están ocupados.

---

## 6. Registro e inicio de sesión

El cliente no debería necesitar registrarse para navegar por la página. El registro/login aparece cuando intenta confirmar una reserva que requiere autenticación.

### Registro

Datos:
- Nombre.
- Apellido.
- Email.
- Contraseña.

Al registrarse:

Firebase Authenication + Firestore

Se crea el documento correspondiente al usuario.

Ejemplo:

usuarios/{iud}

nombre
apellido
email
rol: cliente fechaRegistro


### Roles

Debe existir al menos:
- `admin`
- `cliente`

Un usuario con `rol = admin` puede acceder al panel administrativo. Un cliente que intente acceder al panel administrativo debe ser rechazado/redirigido.

---

## 7. "Mis turnos"

Los clientes registrados deben tener una sección "Mis turnos", donde podrán consultar sus reservas.

Ejemplo:

MIS TURNOS
Barbero: Ezequiel Servicio: Corte + Barba Fecha: 20/09/2026 Hora: 15:30 Estado: Confirmado

[Cancelar turno]


Estados posibles:
- Pendiente
- Confirmado
- Cancelado
- Finalizado

---

## 8. Panel administrativo

El administrador tendrá un panel separado de la página pública. No debería existir una sección innecesaria de "Panel de control" si sus métricas duplican información de otras partes.

El panel puede organizarse en:

ADMINISTRACIÓN
├── Turnos
├── Agenda
├── Servicios
└── Barberos


---

## 9. Administración de turnos

El administrador debe poder:
- Ver turnos.
- Filtrar por fecha.
- Filtrar por barbero.
- Filtrar por estado.
- Cancelar turnos.
- Modificar turnos, si corresponde.
- Consultar información del cliente.
- Consultar servicio.
- Consultar precio.

Ejemplo:

TURNOS

Fecha Hora Cliente Barbero Servicio Estado 20/09 15:00 Juan Ezequiel Fade Confirmado 20/09 16:00 Pedro Isaías Barba Pendiente


---

## 10. Administración de agenda

El administrador debe poder configurar:
- Días de trabajo.
- Horarios.
- Horarios no disponibles.
- Días especiales.
- Vacaciones o días cerrados.
- Disponibilidad de cada barbero.

La agenda debe permitir gestionar la disponibilidad por barbero, ya que existen dos.

---

## 11. Administración de servicios

El administrador debe poder:
- Crear servicio.
- Editar servicio.
- Eliminar servicio.
- Modificar precio.
- Modificar descripción.

Los cambios deben reflejarse automáticamente en la página principal.

ADMIN → Modifica precio del Fade → Firestore → Página principal → Nuevo precio

No debería ser necesario modificar el código para cambiar un servicio.

---

## 12. Administración de barberos

El administrador debe poder:
- Agregar barbero.
- Editar barbero.
- Eliminar/desactivar barbero.
- Modificar nombre.
- Modificar descripción.
- Modificar especialidades.
- Modificar imagen, si se utiliza.

Los cambios realizados desde administración deben reflejarse en la página pública.

**Importante:** si los documentos actuales de barberos no contienen determinados campos, el código no debe intentar acceder a esos campos inexistentes.

---

## 13. Firebase / Firestore

Las principales colecciones serían:
- `usuarios`
- `barberos`
- `servicios` / `precios`
- `turnos`
- `agenda` / `horarios`

La estructura definitiva deberá definirse antes de implementar cambios importantes para evitar que diferentes partes de la aplicación utilicen estructuras distintas.

---

## 14. Seguridad

El sistema debe garantizar que:

### Cliente

Puede:
- Consultar información pública.
- Crear sus propios turnos.
- Consultar sus propios turnos.
- Modificar/cancelar sus propios turnos según las reglas establecidas.

No puede:
- Acceder al panel administrativo.
- Modificar servicios.
- Modificar barberos.
- Modificar otros usuarios.
- Modificar turnos de otros clientes.

### Administrador

Puede gestionar:
- Turnos.
- Agenda.
- Servicios.
- Barberos.

Las reglas de seguridad deben implementarse en Firestore Security Rules, no solamente ocultando botones en Flutter.

---

## 15. Diseño visual

La identidad visual debe mantener un estilo de barbería premium masculina.

### Colores principales

- Negro.
- Dorado `#D4AF37`.
- Blanco.
- Gris oscuro.

### Estilo

- Elegante.
- Moderno.
- Masculino.
- Minimalista.
- Profesional.

### Componentes

Utilizar:
- Tarjetas.
- Botones destacados.
- Bordes y detalles dorados.
- Buena separación entre secciones.
- Animaciones discretas.
- Diseño responsive.

---

## 16. Responsive

La aplicación debe funcionar correctamente en:
- PC.
- Notebook.
- Tablet.
- Teléfono.

No debe limitarse a cambiar el tamaño de los elementos. La interfaz debe adaptar:
- Menús.
- Columnas.
- Tarjetas.
- Calendario.
- Formularios.
- Panel administrativo.

---

## 17. Reglas importantes del sistema

Estas reglas conviene dejarlas escritas porque después sirven muchísimo para OpenCode:

1. Un horario no puede ser reservado dos veces para el mismo barbero.
2. Un cliente debe seleccionar un barbero antes de reservar.
3. La disponibilidad debe corresponder al barbero seleccionado.
4. Los turnos deben almacenarse en Firestore.
5. Los servicios mostrados al cliente deben provenir de Firestore.
6. Los barberos mostrados al cliente deben provenir de Firestore.
7. Los cambios realizados por el administrador deben reflejarse en la página pública.
8. Un cliente no puede acceder a funciones administrativas.
9. La seguridad no debe depender solamente de la interfaz.
10. No se deben llamar campos de Firestore que no existan.
11. No se deben crear datos ficticios para solucionar errores.
12. Antes de modificar código existente, se debe comprobar cómo está implementado actualmente.
