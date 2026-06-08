const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
setGlobalOptions({ region: "southamerica-east1" });

const db = admin.firestore();

const WHATSAPP_TOKEN = process.env.WHATSAPP_TOKEN;
const WHATSAPP_PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID;

function diasNoMes(ano, mes) {
  return new Date(ano, mes, 0).getDate();
}

function dataBaseVencimento(diaVencimento, referencia) {
  const ultimoDia = diasNoMes(
    referencia.getFullYear(),
    referencia.getMonth() + 1
  );

  const diaAjustado = Math.min(diaVencimento, ultimoDia);

  return new Date(
    referencia.getFullYear(),
    referencia.getMonth(),
    diaAjustado,
    0,
    0,
    0,
    0
  );
}

function diferencaEmDias(dataA, dataB) {
  const msPorDia = 24 * 60 * 60 * 1000;
  const a = new Date(dataA.getFullYear(), dataA.getMonth(), dataA.getDate());
  const b = new Date(dataB.getFullYear(), dataB.getMonth(), dataB.getDate());
  return Math.round((a - b) / msPorDia);
}

function limparTelefone(telefone) {
  if (!telefone) return "";
  const soNumeros = String(telefone).replace(/\D/g, "");
  if (!soNumeros) return "";
  return soNumeros.startsWith("55") ? soNumeros : `55${soNumeros}`;
}

function preencherMensagem(template, dados) {
  return String(template || "")
    .replaceAll("{nome}", dados.nome || "")
    .replaceAll("{servico}", dados.servico || "")
    .replaceAll("{valor}", dados.valor || "")
    .replaceAll("{dia_vencimento}", dados.diaVencimento || "");
}

async function enviarWhatsappTexto({ telefone, mensagem }) {
  if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_NUMBER_ID) {
    throw new Error("Variáveis do WhatsApp não configuradas.");
  }

  const url = `https://graph.facebook.com/v23.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`;

  await axios.post(
    url,
    {
      messaging_product: "whatsapp",
      to: telefone,
      type: "text",
      text: {
        preview_url: false,
        body: mensagem,
      },
    },
    {
      headers: {
        Authorization: `Bearer ${WHATSAPP_TOKEN}`,
        "Content-Type": "application/json",
      },
      timeout: 30000,
    }
  );
}

exports.createUserByAdmin = onCall(async (request) => {
  const auth = request.auth;
  const data = request.data || {};

  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const adminDoc = await db.collection("users").doc(auth.uid).get();

  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Perfil do usuário não encontrado.");
  }

  const adminData = adminDoc.data() || {};

  if (adminData.role !== "admin" || adminData.ativo !== true) {
    throw new HttpsError(
      "permission-denied",
      "Apenas administradores ativos podem criar usuários."
    );
  }

  const nome = String(data.nome || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "").trim();
  const role = String(data.role || "").trim().toLowerCase();

  if (!nome) {
    throw new HttpsError("invalid-argument", "Nome é obrigatório.");
  }

  if (!email) {
    throw new HttpsError("invalid-argument", "E-mail é obrigatório.");
  }

  if (!password || password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "A senha deve ter pelo menos 6 caracteres."
    );
  }

  if (role !== "admin" && role !== "funcionario") {
    throw new HttpsError(
      "invalid-argument",
      "Role inválida. Use admin ou funcionario."
    );
  }

  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: nome,
      disabled: false,
    });

    await db.collection("users").doc(userRecord.uid).set({
      nome,
      email,
      role,
      ativo: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: auth.uid,
    });

    return {
      success: true,
      uid: userRecord.uid,
      email,
      role,
    };
  } catch (error) {
    const code = error?.code || "";

    if (code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Este e-mail já está em uso.");
    }

    if (code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "Senha inválida.");
    }

    if (code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "E-mail inválido.");
    }

    console.error("Erro ao criar usuário:", error);
    throw new HttpsError("internal", "Não foi possível criar o usuário.");
  }
});

exports.enviarLembretesMensalidades = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const hoje = new Date();

    const [configSnap, mensalidadesSnap] = await Promise.all([
      db.collection("configuracoes").doc("cobranca").get(),
      db.collection("mensalidades").where("ativa", "==", true).get(),
    ]);

    const config = configSnap.data() || {};

    const lembrete1Ativo = config.lembrete1Ativo === true;
    const diasAntesLembrete1 = Number(config.diasAntesLembrete1 ?? 3);
    const mensagemLembrete1 = String(config.mensagemLembrete1 ?? "");

    const lembrete2Ativo = config.lembrete2Ativo === true;
    const diasAntesLembrete2 = Number(config.diasAntesLembrete2 ?? 1);
    const mensagemLembrete2 = String(config.mensagemLembrete2 ?? "");

    for (const mensalidadeDoc of mensalidadesSnap.docs) {
      const mensalidade = mensalidadeDoc.data();

      const status = String(mensalidade.status ?? "pendente").toLowerCase();
      if (status === "pago" || status === "cancelado") continue;

      const diaVencimento = Number(mensalidade.diaVencimento ?? 1);
      const vencimento = dataBaseVencimento(diaVencimento, hoje);
      const diasParaVencer = diferencaEmDias(vencimento, hoje);

      const clienteId = String(mensalidade.clienteId ?? "");
      if (!clienteId) continue;

      const clienteSnap = await db.collection("clientes").doc(clienteId).get();
      const cliente = clienteSnap.data() || {};

      const telefone = limparTelefone(cliente.telefone);
      if (!telefone) continue;

      const payloadMensagem = {
        nome: String(mensalidade.nomeCliente ?? cliente.nome ?? ""),
        servico: String(mensalidade.nomeServico ?? ""),
        valor: `R$ ${Number(mensalidade.valorFinal ?? mensalidade.valor ?? 0)
          .toFixed(2)
          .replace(".", ",")}`,
        diaVencimento: String(diaVencimento),
      };

      const refMesAtual = `${hoje.getFullYear()}-${String(
        hoje.getMonth() + 1
      ).padStart(2, "0")}`;

      const updateData = {};

      if (
        lembrete1Ativo &&
        diasParaVencer === diasAntesLembrete1 &&
        mensalidade.ultimoEnvioLembrete1Ref !== refMesAtual
      ) {
        const mensagem = preencherMensagem(mensagemLembrete1, payloadMensagem);
        await enviarWhatsappTexto({ telefone, mensagem });
        updateData.ultimoEnvioLembrete1Ref = refMesAtual;
      }

      if (
        lembrete2Ativo &&
        diasParaVencer === diasAntesLembrete2 &&
        mensalidade.ultimoEnvioLembrete2Ref !== refMesAtual
      ) {
        const mensagem = preencherMensagem(mensagemLembrete2, payloadMensagem);
        await enviarWhatsappTexto({ telefone, mensagem });
        updateData.ultimoEnvioLembrete2Ref = refMesAtual;
      }

      if (Object.keys(updateData).length > 0) {
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await mensalidadeDoc.ref.update(updateData);
      }
    }
  }
);