/**
 * The subset of the Artifact viewer's runtime host this app touches. It exists
 * only when the page is published as a claude.ai Artifact; in an ordinary
 * browser `claude` is undefined, so every use must be guarded.
 */
interface ClaudeDownloads {
  save(request: { filename: string; data: string | Blob | ArrayBuffer }): Promise<{ status: 'saved' }>
}

interface ClaudeHost {
  /** Resolves the capability namespace, or null when this view cannot run it. */
  use(name: 'downloads'): Promise<ClaudeDownloads | null>
}

declare const claude: ClaudeHost | undefined
