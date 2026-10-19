// Inline photos for Hermes' existing multimodal run API. No Mac paths are sent to the container.
import fs from 'node:fs'
import path from 'node:path'
const fail = (message, status = 400) => Object.assign(new Error(message), { status })
export function photoInput(text, files, dir) {
  if (!files?.length) return text
  if (files.length > 4) throw fail('Choisis au maximum quatre photos.')
  let root
  try { root = fs.realpathSync(path.join(dir, 'uploads')) } catch { throw fail('Les photos ne sont plus disponibles. Sélectionne-les à nouveau.') }
  let total = 0
  const parts = [{ type: 'text', text: text?.trim() || 'Décris les photos jointes.' }]
  for (const file of files) {
    let actual, stat
    try { actual = fs.realpathSync(file); stat = fs.statSync(actual) } catch { throw fail('Une photo n’est plus disponible. Sélectionne-la à nouveau.') }
    if (path.dirname(actual) !== root || !stat.isFile()) throw fail('Cette pièce jointe ne provient pas des photos importées.')
    total += stat.size
    if (stat.size > 4 * 1024 * 1024 || total > 6 * 1024 * 1024) throw fail('Ces photos sont trop volumineuses. Réduis leur taille ou envoie-les séparément.', 413)
    const bytes = fs.readFileSync(actual)
    const mime = bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff])) ? 'image/jpeg'
      : bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ? 'image/png'
      : ['GIF87a','GIF89a'].includes(bytes.subarray(0, 6).toString()) ? 'image/gif'
      : bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP' ? 'image/webp' : null
    if (!mime) throw fail('Seules les photos JPEG, PNG, GIF et WebP sont prises en charge. Choisis une photo dans la photothèque.')
    parts.push({ type: 'image_url', image_url: { url: `data:${mime};base64,${bytes.toString('base64')}` } })
  }
  return [{ role: 'user', content: parts }]
}
