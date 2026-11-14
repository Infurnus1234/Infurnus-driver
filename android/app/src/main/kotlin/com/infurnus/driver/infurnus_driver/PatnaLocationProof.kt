package com.infurnus.driver.infurnus_driver

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec

internal object PatnaLocationProof {
    private const val alias = "infurnus_patna_mock_gps_v1"
    private var reportedSession: String? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, "infurnus/patna_location_proof").setMethodCallHandler { call, result ->
            if (call.method != "sign") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val driver = requireNotNull(call.argument<String>("driver"))
                val session = requireNotNull(call.argument<String>("session"))
                val timestamp = requireNotNull(call.argument<String>("timestamp"))
                val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                if (!keys.containsAlias(alias)) {
                    KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
                        initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                            .setDigests(KeyProperties.DIGEST_SHA256)
                            .build())
                    }.generateKeyPair()
                }
                val entry = keys.getEntry(alias, null) as KeyStore.PrivateKeyEntry
                if (reportedSession != session) {
                    reportedSession = session
                    Log.i("InfurnusPatnaProof", "driver=$driver session=$session publicKey=" +
                        Base64.encodeToString(entry.certificate.publicKey.encoded, Base64.NO_WRAP))
                }
                val message = listOf("infurnus:patna-mock-location:v1", driver, session, timestamp).joinToString("\n")
                val signed = Signature.getInstance("SHA256withECDSA").run {
                    initSign(entry.privateKey)
                    update(message.toByteArray(Charsets.UTF_8))
                    sign()
                }
                result.success(Base64.encodeToString(signed, Base64.NO_WRAP))
            } catch (_: Exception) {
                result.error("DEVICE_PROOF_UNAVAILABLE", "Could not sign the location sample", null)
            }
        }
    }
}
