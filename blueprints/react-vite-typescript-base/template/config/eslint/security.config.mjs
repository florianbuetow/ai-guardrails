import tseslint from 'typescript-eslint'
import security from 'eslint-plugin-security'
import noUnsanitized from 'eslint-plugin-no-unsanitized'

export default tseslint.config({
  files: ['**/*.{ts,tsx}'],
  extends: [security.configs.recommended, noUnsanitized.configs.recommended],
  languageOptions: {
    parser: tseslint.parser,
  },
})
