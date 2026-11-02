import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import net from 'node:net';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-double-edge-local';
const EMULATOR_HOST = '127.0.0.1';
const EMULATOR_PORT = 8080;
const CLIENT_UID = 'test-client';
const SLOT_ID = 'B1_test-date_10:00';

let testEnvironment;

function assertEmulatorIsAvailable() {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({
      host: EMULATOR_HOST,
      port: EMULATOR_PORT,
    });
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(
        `Firestore Emulator is unavailable at ${EMULATOR_HOST}:${EMULATOR_PORT}. ` +
        'Start it with the approved Firebase emulators:exec command.',
      ));
    }, 2000);

    socket.once('connect', () => {
      clearTimeout(timeout);
      socket.end();
      resolve();
    });
    socket.once('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(
        `Cannot connect to Firestore Emulator at ${EMULATOR_HOST}:${EMULATOR_PORT}: ${error.message}`,
      ));
    });
  });
}

function bookingData({
  userId = CLIENT_UID,
  includePhone = true,
  extraFields = {},
} = {}) {
  const data = {
    userId,
    customerName: 'Cliente de prueba',
    customerEmail: 'cliente@example.test',
    customerPhone: '+54 9 11 1234-5678',
    barberId: 'B1',
    barberName: 'Barbero de prueba',
    barberPhone: '5491112345678',
    serviceId: 'service-test',
    serviceName: 'Servicio de prueba',
    servicePrice: 1000,
    date: '28 de octubre de 2026',
    time: '10:00 - 10:30',
    startTime: '10:00',
    status: 'pending',
    appointmentDateTime: Timestamp.fromDate(
      new Date('2026-10-28T13:00:00.000Z'),
    ),
    timestamp: serverTimestamp(),
    ...extraFields,
  };

  if (!includePhone) delete data.customerPhone;
  return data;
}

async function createBooking(options = {}) {
  const db = testEnvironment.authenticatedContext(CLIENT_UID).firestore();
  const appointmentRef = doc(db, 'turnos', SLOT_ID);
  const availabilityRef = doc(db, 'disponibilidad', SLOT_ID);

  await runTransaction(db, async (transaction) => {
    await transaction.get(appointmentRef);
    transaction.set(appointmentRef, bookingData(options));
    transaction.set(availabilityRef, {
      barberId: 'B1',
      date: '28 de octubre de 2026',
      startTime: '10:00',
      status: 'pending',
      turnoId: SLOT_ID,
    });
  });

  return { db, appointmentRef, availabilityRef };
}

describe('Firestore rules: customer phone on appointments', () => {
  before(async () => {
    await assertEmulatorIsAvailable();
    const rules = await readFile(
      new URL('../../firestore.rules', import.meta.url),
      'utf8',
    );

    testEnvironment = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: EMULATOR_HOST,
        port: EMULATOR_PORT,
        rules,
      },
    });
  });

  after(async () => {
    await testEnvironment?.cleanup();
  });

  beforeEach(async () => {
    await testEnvironment.clearFirestore();
  });

  it('creates a turn with customerPhone and its public availability mirror without the phone', async () => {
    const { db, appointmentRef, availabilityRef } = await assertSucceeds(
      createBooking(),
    );
    const appointment = await assertSucceeds(getDoc(appointmentRef));
    const availability = await assertSucceeds(getDoc(availabilityRef));

    assert.equal(appointment.data().customerPhone, '+54 9 11 1234-5678');
    assert.equal(availability.data().turnoId, SLOT_ID);
    assert.equal(Object.hasOwn(availability.data(), 'customerPhone'), false);
  });

  it('rejects a client-created turn when customerPhone is absent', async () => {
    await assertFails(createBooking({ includePhone: false }));
  });

  it('rejects a turn whose userId does not match the authenticated client', async () => {
    await assertFails(createBooking({ userId: 'another-client' }));
  });

  it('rejects a turn containing a field not permitted by the rules', async () => {
    await assertFails(
      createBooking({ extraFields: { unapprovedField: 'not allowed' } }),
    );
  });
});
