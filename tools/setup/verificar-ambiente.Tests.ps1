#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'verificar-ambiente.ps1')
}

Describe 'Test-CaminhoSemEspaco' {
    It 'aceita C:\gr' {
        Test-CaminhoSemEspaco 'C:\gr' | Should -BeTrue
    }
    It 'recusa a pasta do projeto, que tem espaço' {
        Test-CaminhoSemEspaco 'C:\Users\Gabriel\Desktop\Acesso remoto' | Should -BeFalse
    }
}

Describe 'Test-Ferramenta' {
    It 'aprova versão acima do mínimo e extrai o número' {
        $r = Test-Ferramenta -Nome 'git' -Comando { 'git version 2.45.1' } -VersaoMinima '2.40'
        $r.Ok | Should -BeTrue
        $r.Versao | Should -Be '2.45.1'
    }
    It 'reprova versão abaixo do mínimo e dá uma dica' {
        $r = Test-Ferramenta -Nome 'git' -Comando { 'git version 2.45.1' } -VersaoMinima '3.0'
        $r.Ok | Should -BeFalse
        $r.Dica | Should -Not -BeNullOrEmpty
    }
    It 'reprova quando o comando lança exceção' {
        $r = Test-Ferramenta -Nome 'git' -Comando { throw 'não encontrado' } -VersaoMinima '2.40'
        $r.Ok | Should -BeFalse
    }
}
