#!/usr/bin/env node
/* App Store Connect automation: mint a JWT from the .p8 API key (using only
 * Node builtins — no external deps), then ensure the bundle ID, distribution
 * profile, and app record exist. Idempotent — safe to re-run.
 *
 * Env required:
 *   ASC_KEY_ID     (e.g. A4MNMMCCVB)
 *   ASC_ISSUER_ID  (UUID from App Store Connect -> Users and Access -> Integrations)
 *   ASC_KEY_PATH   (path to AuthKey_<KEYID>.p8)
 *   ASC_TEAM_ID    (e.g. NK5P69WG2H)            [used only for logging]
 *   APP_BUNDLE_ID  (com.scaleupapp.ios)
 *   APP_NAME       ("ScaleUp: AI Career Coach")
 *   APP_SKU        (e.g. scaleup-ios-001)
 *   PROFILE_NAME   (e.g. "ScaleUp iOS AppStore" — must match ExportOptions.plist)
 */
const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const BUNDLE = process.env.APP_BUNDLE_ID || 'com.scaleupapp.ios';
const NAME = process.env.APP_NAME || 'ScaleUp: AI Career Coach';
const SKU = process.env.APP_SKU || 'scaleup-ios-001';
const PROFILE_NAME = process.env.PROFILE_NAME || 'ScaleUp iOS AppStore';

if (!KEY_ID || !ISSUER || !KEY_PATH) {
    console.error('Missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH');
    process.exit(2);
}

function b64url(input) {
    return Buffer.from(input)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');
}

// Zero-dependency ES256 JWT (App Store Connect API auth token), signed with
// Node's builtin crypto module. `dsaEncoding: 'ieee-p1363'` produces the raw
// fixed-length r||s signature JOSE/JWS requires (as opposed to the default
// ASN.1/DER encoding OpenSSL normally uses for ECDSA).
function token() {
    const key = fs.readFileSync(KEY_PATH);
    const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = { iss: ISSUER, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' };
    const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
    const sign = crypto.createSign('SHA256');
    sign.update(signingInput);
    sign.end();
    const sigDer = sign.sign({ key, dsaEncoding: 'ieee-p1363' });
    const sig = sigDer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    return `${signingInput}.${sig}`;
}

function api(method, path, body) {
    return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const req = https.request({
            method,
            hostname: 'api.appstoreconnect.apple.com',
            path: `/v1${path}`,
            headers: {
                Authorization: `Bearer ${token()}`,
                'Content-Type': 'application/json',
                ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
            },
        }, (res) => {
            let data = '';
            res.on('data', (c) => { data += c; });
            res.on('end', () => {
                let json = null;
                try { json = data ? JSON.parse(data) : null; } catch { /* ignore */ }
                if (res.statusCode >= 200 && res.statusCode < 300) resolve(json);
                else reject(new Error(`${method} ${path} -> ${res.statusCode}: ${JSON.stringify(json || data).slice(0, 500)}`));
            });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });
}

async function ensureBundleId() {
    const existing = await api('GET', `/bundleIds?filter[identifier]=${encodeURIComponent(BUNDLE)}&limit=200`);
    const found = (existing.data || []).find((b) => b.attributes.identifier === BUNDLE);
    if (found) { console.log(`✓ bundleId exists: ${BUNDLE} (${found.id})`); return found.id; }
    const created = await api('POST', '/bundleIds', {
        data: { type: 'bundleIds', attributes: { identifier: BUNDLE, name: NAME.replace(/[^A-Za-z0-9 ]/g, ''), platform: 'IOS' } },
    });
    console.log(`✓ bundleId created: ${BUNDLE} (${created.data.id})`);
    return created.data.id;
}

async function ensureProfile(bundleResourceId) {
    const existing = await api('GET', `/profiles?filter[name]=${encodeURIComponent(PROFILE_NAME)}&include=bundleId&limit=200`);
    let prof = (existing.data || []).find((p) => p.attributes.name === PROFILE_NAME && p.attributes.profileState === 'ACTIVE');
    if (!prof) {
        const certs = await api('GET', '/certificates?limit=200');
        const dist = (certs.data || []).find((c) => /DISTRIBUTION/.test(c.attributes.certificateType));
        if (!dist) throw new Error('No Distribution certificate found in the account.');
        const created = await api('POST', '/profiles', {
            data: {
                type: 'profiles',
                attributes: { name: PROFILE_NAME, profileType: 'IOS_APP_STORE' },
                relationships: {
                    bundleId: { data: { type: 'bundleIds', id: bundleResourceId } },
                    certificates: { data: [{ type: 'certificates', id: dist.id }] },
                },
            },
        });
        prof = created.data;
    }
    // Download + install the profile so xcodebuild can sign with it.
    const full = await api('GET', `/profiles/${prof.id}?fields[profiles]=profileContent,uuid,name`);
    const a = full.data.attributes;
    const dir = `${process.env.HOME}/Library/MobileDevice/Provisioning Profiles`;
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(`${dir}/${a.uuid}.mobileprovision`, Buffer.from(a.profileContent, 'base64'));
    console.log(`✓ profile ready: ${a.name} (${a.uuid})`);
}

async function appExists() {
    const existing = await api('GET', `/apps?filter[bundleId]=${encodeURIComponent(BUNDLE)}&limit=200`);
    return (existing.data || [])[0];
}

(async () => {
    console.log(`ASC automation · team ${process.env.ASC_TEAM_ID || '?'} · key ${KEY_ID}`);
    const bundleResourceId = await ensureBundleId();
    await ensureProfile(bundleResourceId);
    const app = await appExists();
    if (app) {
        console.log(`✓ app record exists: ${NAME} (${app.id})`);
    } else {
        // Apple provides NO API to create an app record — it must be done once
        // in the App Store Connect UI. The build still archives/exports; only
        // the upload step needs the record.
        console.log('');
        console.log('⚠️  APP RECORD MISSING — create it once (Apple has no API for this):');
        console.log('    App Store Connect -> Apps -> + -> New App');
        console.log(`    Platform: iOS · Name: ${NAME} · Language: English (U.S.)`);
        console.log(`    Bundle ID: ${BUNDLE} · SKU: ${SKU}`);
        console.log('    Then re-run this script — it will upload.');
    }
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
